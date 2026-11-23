<?php

declare(strict_types=1);

$socket = new ZMQSocket(new ZMQContext(1, false), ZMQ::SOCKET_REP);
$socket->setSockOpt(ZMQ::SOCKOPT_RCVTIMEO, 5000);
$socket->setSockOpt(ZMQ::SOCKOPT_SNDTIMEO, 5000);
$socket->setSockOpt(ZMQ::SOCKOPT_LINGER, 1000);
$socket->bind('tcp://127.0.0.1:*');

fwrite(STDOUT, $socket->getSockOpt(ZMQ::SOCKOPT_LAST_ENDPOINT) . PHP_EOL);

for ($i = 0; $i < (int) $argv[1]; $i++) {
    $request = $socket->recv();
    if ($request === false || $socket->send('Reply: ' . $request) === false) {
        throw new RuntimeException('The ZeroMQ test exchange timed out.');
    }
}
