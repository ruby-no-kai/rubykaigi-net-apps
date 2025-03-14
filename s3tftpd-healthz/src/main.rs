#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();
    let app = axum::Router::new().route("/ping", axum::routing::get(ping));
    let addr = std::net::SocketAddr::from(([0, 0, 0, 0], 8080));
    let listener = tokio::net::TcpListener::bind(&addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn ping() -> (axum::http::StatusCode, &'static str) {
    match run_ping().await {
        Ok(_) => (axum::http::StatusCode::OK, "ok"),
        Err(e) => {
            tracing::error!(e=?e,"Error");
            (axum::http::StatusCode::INTERNAL_SERVER_ERROR, "not ok")
        }
    }
}

async fn run_ping() -> Result<(), anyhow::Error> {
    let data = start().await?;
    let s = String::from_utf8_lossy(&data);
    if !s.contains(r#"{"ok": true}"#) {
        tracing::error!(s=?s, "not ok");
        return Err(anyhow::anyhow!("not ok..."));
    }
    Ok(())
}

#[derive(Debug)]
struct State {
    data: Vec<u8>,
    sock: tokio::net::UdpSocket,
    tx: Option<Vec<u8>>,
    awaiting_data: ttftp::client::download::AwaitingData,
    addr: Option<std::net::SocketAddr>,
}

#[derive(Debug)]
enum Next {
    //AwaitingData(Option<Vec<u8>>, ttftp::client::download::AwaitingData),
    Intermediate(
        Option<Vec<u8>>,
        ttftp::client::download::AwaitingData,
        Vec<u8>,
    ),
    Final(Option<Vec<u8>>, Vec<u8>),
    Retransmission(Option<Vec<u8>>, ttftp::client::download::AwaitingData),
    Error(Option<Vec<u8>>, anyhow::Error),
}

fn process(rx: &[u8], next: ttftp::client::download::AwaitingData) -> Next {
    let mut tx = [0u8; ttftp::PACKET_SIZE];
    let (result, send) = next.process(rx, &mut tx);
    let tx_vec = if let Some(send) = send {
        Some(tx[..send].to_vec())
    } else {
        None
    };
    let retval = match result {
        Ok(ttftp::client::download::BlockReceived::Intermediate(awaiting_data, block)) => {
            Next::Intermediate(tx_vec, awaiting_data, block.to_vec())
        }
        Ok(ttftp::client::download::BlockReceived::Final(block)) => {
            Next::Final(tx_vec, block.to_vec())
        }
        Ok(ttftp::client::download::BlockReceived::Retransmission(state)) => {
            Next::Retransmission(tx_vec, state)
        }
        Err(e) => Next::Error(tx_vec, anyhow::anyhow!(e.to_string())),
    };
    tracing::trace!(next=?retval,  "process");
    retval
}

async fn start() -> Result<Vec<u8>, anyhow::Error> {
    let mut tx = [0u8; ttftp::PACKET_SIZE];
    let filename = std::ffi::CStr::from_bytes_with_nul(b"ping\0").unwrap();
    let (awaiting_data, send) =
        ttftp::client::download::new(&mut tx, filename, ttftp::Mode::Octect)?;
    let sock = tokio::net::UdpSocket::bind((std::net::Ipv4Addr::new(127, 0, 0, 1), 0)).await?;

    sock.send_to(&tx[..send], (std::net::Ipv4Addr::new(127, 0, 0, 1), 69))
        .await?;

    let data = perform(State {
        data: vec![],
        sock,
        tx: None,
        awaiting_data,
        addr: None,
    })
    .await?;

    Ok(data)
}

async fn perform(state: State) -> Result<Vec<u8>, anyhow::Error> {
    tracing::trace!(state=?state,  "perform");
    let sock = state.sock;
    if let Some(pend_tx) = state.tx {
        tracing::trace!(pend_tx=?pend_tx,  "send");
        sock.send_to(&pend_tx, state.addr.unwrap()).await?;
    }
    let mut data = state.data;
    let awaiting_data = state.awaiting_data;

    tracing::trace!("recv...");
    let mut rx = [0u8; ttftp::PACKET_SIZE];
    let (received, addr) = sock.recv_from(&mut rx).await?;
    let addr = Some(addr);
    let mut retry = false;
    if state.addr.is_none() {
        if addr.unwrap().ip() != std::net::Ipv4Addr::new(127, 0, 0, 1) {
            tracing::warn!(addr=?addr, "Unexpected addr");
            retry = true;
        } else {
        }
        tracing::trace!(remote_addr=?addr, "addr");
    } else if state.addr != addr {
        tracing::warn!(addr=?addr, state_addr=?state.addr, "Unexpected addr");
        retry = true
    }
    if retry {
        return Box::pin(perform(State {
            data,
            sock,
            tx: None,
            awaiting_data,
            addr,
        }))
        .await;
    }
    tracing::trace!(rx=?rx[..received],  "recv");
    let next = process(&rx[..received], awaiting_data);
    match next {
        Next::Intermediate(tx, awaiting_data, block) => {
            data.extend_from_slice(&block);
            return Box::pin(perform(State {
                data,
                sock,
                tx,
                awaiting_data,
                addr,
            }))
            .await;
        }
        Next::Final(tx, block) => {
            send_maybe(tx.as_deref(), addr.as_ref(), &sock).await?;
            data.extend_from_slice(&block);
            return Ok(data);
        }
        Next::Retransmission(tx, awaiting_data) => {
            return Box::pin(perform(State {
                data,
                sock,
                tx,
                awaiting_data,
                addr,
            }))
            .await
        }
        Next::Error(tx, e) => {
            send_maybe(tx.as_deref(), addr.as_ref(), &sock).await?;
            tracing::error!(e=?e,  "Error");
            return Err(e.into());
        }
    }
}

async fn send_maybe(
    buf: Option<&[u8]>,
    addr: Option<&std::net::SocketAddr>,
    sock: &tokio::net::UdpSocket,
) -> Result<(), anyhow::Error> {
    match (buf, addr) {
        (Some(buf), Some(addr)) => {
            if let Err(e) = sock.send_to(buf, addr).await {
                tracing::warn!(e=?e, "Error sending (send_maybe)");
            }
        }
        (Some(_), None) => {
            tracing::warn!("missing addr for send_maybe");
        }
        (None, Some(_)) => {}
        (None, None) => {}
    }
    Ok(())
}
