package safe_socket

import "io"

// SendAll writes all of bytes to socket, looping over Write to handle short
// writes (a single Write call is not guaranteed to send the whole buffer).
func SendAll(socket io.Writer, bytes []byte) error {
	totalWritten := 0
	for totalWritten < len(bytes) {
		n, err := socket.Write(bytes[totalWritten:])
		if err != nil {
			return err
		}
		totalWritten += n
	}
	return nil
}

// RecvAll reads exactly size bytes from socket, looping over Read to handle
// short reads (a single Read call may return fewer bytes than requested).
func RecvAll(socket io.Reader, size int) ([]byte, error) {
	buff := make([]byte, size)
	totalRead := 0
	for totalRead < size {
		n, err := socket.Read(buff[totalRead:])
		totalRead += n
		if err != nil {
			if err == io.EOF && totalRead == size {
				break
			}
			return nil, err
		}
	}
	return buff, nil
}
