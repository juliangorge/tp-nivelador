package client

import (
	"bufio"
	"net"
	"os"
	"time"

	"github.com/7574-sistemas-distribuidos/tp-nivelador/src/logger"
	"github.com/7574-sistemas-distribuidos/tp-nivelador/src/safe_socket"
)

const CONNECTION_ATTEMPTS_MAX = 3
const CONNECTION_ATTEMPS_DELAY_MS = 200

const RESPONSE_BUFFER_SIZE = 1024

type ClientConfig struct {
	ServerHost string
	ServerPort string
	AgencyId   string
	InputFile  string
	OutputFile string
}

type Client struct {
	conn   net.Conn
	config ClientConfig
}

func NewClient(config ClientConfig) (*Client, error) {
	conn, err := connectToServer(config.ServerHost, config.ServerPort)
	if err != nil {
		logger.Warn("connect-to-server", logger.Fail)
		return nil, err
	}

	client := &Client{conn: conn, config: config}
	return client, nil
}

func connectToServer(host, port string) (net.Conn, error) {
	const action = "connect-to-server"
	var err error
	var conn net.Conn

	logger.Info(action, logger.InProgress)
	for i := range CONNECTION_ATTEMPTS_MAX {
		conn, err = net.Dial("tcp", host+":"+port)
		if err != nil {
			logger.Warn(action, logger.Fail, "attempt", i)
			time.Sleep(CONNECTION_ATTEMPS_DELAY_MS * time.Millisecond)
			continue
		}

		logger.Info(action, logger.Success)
		break
	}

	return conn, err
}

func (client *Client) Run() error {
	const mainAction = "process-bets"
	defer client.conn.Close()

	inputFile, err := os.Open(client.config.InputFile)
	if err != nil {
		logger.Error(mainAction, logger.Fail, "err", err)
		return err
	}
	defer inputFile.Close()

	outputFile, err := os.Create(client.config.OutputFile)
	if err != nil {
		logger.Error(mainAction, logger.Fail, "err", err)
		return err
	}
	defer outputFile.Close()

	writer := bufio.NewWriter(outputFile)
	defer writer.Flush()

	logger.Info(mainAction, logger.InProgress, "agency-id", client.config.AgencyId)

	scanner := bufio.NewScanner(inputFile)
	betAmount := 0
	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			continue
		}

		betArgs := []any{"agency-id", client.config.AgencyId, "bet-id", betAmount}

		if err := safe_socket.SendAll(client.conn, []byte(line)); err != nil {
			logger.Error("send-bet", logger.Fail, betArgs...)
			return err
		}

		response, err := safe_socket.RecvAll(client.conn, RESPONSE_BUFFER_SIZE)
		if err != nil {
			logger.Error("recv-response", logger.Fail, betArgs...)
			return err
		}

		if _, err := writer.WriteString(string(response) + "\n"); err != nil {
			logger.Error("persist-response", logger.Fail, betArgs...)
			return err
		}

		betAmount++
	}

	if err := scanner.Err(); err != nil {
		logger.Error(mainAction, logger.Fail, "err", err)
		return err
	}

	logger.Info(mainAction, logger.Success, "agency-id", client.config.AgencyId, "bets-amount", betAmount)
	return nil
}
