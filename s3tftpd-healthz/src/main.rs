#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();
    let app = axum::Router::new().route("/ping", axum::routing::get(get_ping));
    let addr = std::net::SocketAddr::from(([0, 0, 0, 0], 8080));
    let listener = tokio::net::TcpListener::bind(&addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn get_ping() -> (axum::http::StatusCode, &'static str) {
    match tokio::time::timeout(std::time::Duration::from_secs(5), do_ping()).await {
        Ok(Ok(_)) => (axum::http::StatusCode::OK, "ok"),
        Err(e) => {
            tracing::error!(e=?e,"Timeout");
            (axum::http::StatusCode::GATEWAY_TIMEOUT, "timeout")
        }
        Ok(Err(e))=> {
            tracing::error!(e=?e,"Error");
            (axum::http::StatusCode::INTERNAL_SERVER_ERROR, "not ok")
        }
    }
}

async fn do_ping() -> Result<(), anyhow::Error> {
    let mut tx = [0u8; ttftp::PACKET_SIZE];
    let mut rx = [0u8; ttftp::PACKET_SIZE];
    let filename = c"ping";
    let (mut state, send) = ttftp::client::download::new(&mut tx, filename, ttftp::Mode::Octect)?;

    let mut data = vec![];
    let sock = tokio::net::UdpSocket::bind((std::net::Ipv4Addr::new(127, 0, 0, 1), 0)).await?;
    sock.send_to(&tx[..send], (std::net::Ipv4Addr::new(127, 0, 0, 1), 69))
        .await?;
    let mut raddr = None;

    loop {
        let (received, paddr) = sock.recv_from(&mut rx).await?;
        if raddr.is_none() {
            raddr = Some(paddr);
        } else if raddr != Some(paddr) {
            tracing::error!(remote=?raddr,received=?paddr,"received packet from unexpected address");
            continue;
        }
        let (result, send) = state.process(&rx[..received], &mut tx);
        if let Some(send) = send {
            sock.send_to(&tx[..send], raddr.unwrap()).await?;
        }
        state = match result {
            Ok(ttftp::client::download::BlockReceived::Intermediate(awaiting_data, block)) => {
                data.extend_from_slice(block);
                awaiting_data
            }
            Ok(ttftp::client::download::BlockReceived::Final(block)) => {
                data.extend_from_slice(block);
                break;
            }
            Ok(ttftp::client::download::BlockReceived::Retransmission(state)) => state,
            Err(e) => return Err(anyhow::anyhow!(e.to_string())),
        }
    }

    Ok(())
}
