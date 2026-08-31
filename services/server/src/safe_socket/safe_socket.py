import socket


def recv_all(socket: socket.socket, size):
    """Reads exactly `size` bytes from `socket`, looping over `recv` to
    handle short reads (a single `recv` call may return fewer bytes than
    requested)."""
    data = bytearray()
    while len(data) < size:
        chunk = socket.recv(size - len(data))
        if not chunk:
            raise ConnectionError(
                "connection closed before receiving all expected bytes"
            )
        data.extend(chunk)
    return bytes(data)


def send_all(socket: socket.socket, bytes):
    """Sends all of `bytes` through `socket`, looping over `send` to handle
    short writes: a single `send` call is not guaranteed to send the whole
    buffer, and may legitimately send 0 bytes without the connection being
    closed (unlike `recv`, a closed connection surfaces as an exception from
    `send`, not as a 0 return value)."""
    total_sent = 0
    while total_sent < len(bytes):
        sent = socket.send(bytes[total_sent:])
        total_sent += sent
