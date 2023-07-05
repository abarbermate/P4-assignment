# Simple TCP endpoint in P4

### Created by: Lilla Novák, Bálint Balázs, Máté Barbér

## Introduction

This repository contains an implementation of a simple TCP endpoint using the P4 language. The endpoint supports the following functionalities:

**Three-way handshake:** The process of establishing a TCP connection consists of three steps, where the server and the client send different flags to each other to establish the connection.

**State maintenance:** The TCP endpoint has to keep track of several states, such as connection establishment, data transfer and connection termination. It is important to ensure that the correct state is maintained in the TCP endpoint.

**ACKs to incoming packets:** The server should send ACK responses to incoming packets, this ensures the reliability of the TCP protocol. It is important that ACK messages are sent in the correct order and at the right time.

**Dummy server logic – eating the incoming bytes:** When data arrives at the TCP endpoint, it must be processed and/or placed correctly.

**Connection close:** Closing a TCP connection is not a simple process and care must be taken during implementation to close it correctly. This includes sending the necessary messages to the other party, releasing connection resources and updating the state correctly.

These elements collectively enable the P4 TCP endpoint to establish and maintain TCP connections, handle data transmission and acknowledgment, generate dummy traffic for testing, and manage the closure of connections.

## P4 Program Structure

The P4 program consists of several components that work together to implement the TCP endpoint functionality. Here is an overview of the components:

### Headers

The program defines three header types: ethernet_t, ipv4_t, and tcp_t. These headers represent the Ethernet, IPv4, and TCP headers, respectively. They define the structure of the corresponding packet headers.

### Parser

The MyParser parser is responsible for extracting header fields from incoming packets. It starts by parsing the Ethernet header and then proceeds to the IPv4 header based on the EtherType field. Finally, it parses the TCP header based on the Protocol field in the IPv4 header.

### Controls

The program includes several control blocks that define the behavior of the switch in different stages of packet processing:

**MyVerifyChecksum:** This control block verifies the checksum of the IPv4 and TCP headers to ensure the integrity of the received packet.

**MyIngress:** This control block handles the logic for processing incoming packets. It implements the TCP endpoint functionalities, including generating ACK responses, handling SYN and FIN flags, and forwarding packets.

**MyEgress:** This control block is currently empty and does not perform any operations. It can be extended to implement egress packet processing if needed.

**MyComputeChecksum:** This control block calculates the checksum for the modified IPv4 and TCP headers before sending the packet out.

**MyDeparser:** This control block assembles the modified headers into the outgoing packet.

## How to Use

To run this example, clone the repository in your Mininet BMv2 enviroment, then open the folder called `implementation` in terminal and run the following command:

```
make
```
This command compiles the `basic.p4` file and starts the pod-topo in Mininet and configures all switches with the appropriate P4 program + table entries, and
configures all hosts with the commands listed in pod-topo/topology.json

After the mininet started correctly, run this command:

```
xterm h1
```

When a new terminal windows appears in your screen, initiate a TCP connection to the server using the nc command:

```
nc 10.0.3.3 75
```

This command establishes a connection to the server running on IP address 10.0.3.3 and port 75.

After that, everything you write in your console before you hit the `Enter` button will be sent to the server, then it will be processed and sent back to you.

## Additional Notes

This P4 program is a simplified implementation of a TCP endpoint and may not be suitable for production use. It serves as a learning example and can be extended to support additional features or optimized for specific use cases but in this state this is an assignment for one of our university classes.
