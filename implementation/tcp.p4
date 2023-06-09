#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4 = 0x800;
const bit<8> TYPE_TCP = 6;

typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

header ethernet_t {
	macAddr_t dstAddr;
	macAddr_t srcAddr;
	bit<16> etherType;
}

header ipv4_t {
	bit<4> version;
	bit<4> ihl;
	bit<8> diffserv;
	bit<16> totalLen;
	bit<16> identification;
	bit<3> flags;
	bit<13> fragOffset;
	bit<8> ttl;
	bit<8> protocol;
	bit<16> hdrChecksum;
	ip4Addr_t srcAddr;
	ip4Addr_t dstAddr;
}

header tcp_t {
	bit<16> srcPort;
	bit<16> dstPort;
	bit<32> seqNo;
	bit<32> ackNo;
	bit<4> dataOffset;
	bit<4> res;
	bit<1> cwr;
	bit<1> ece;
	bit<1> urg;
	bit<1> ack;
	bit<1> psh;
	bit<1> rst;
	bit<1> syn;
	bit<1> fin;
	bit<16> window;
	bit<16> checksum;
	bit<16> urgentPtr;
}

struct metadata {
	bit<16> tcpLength;
}

struct headers {
	ethernet_t ethernet;
	ipv4_t ipv4;
	tcp_t tcp;
}

parser MyParser(packet_in packet, out headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
	state start {
		transition parse_ethernet;
	}

	state parse_ethernet {
		packet.extract(hdr.ethernet);

		transition select(hdr.ethernet.etherType) {
			TYPE_IPV4: parse_ipv4;
			default: accept;
		}
	}

	state parse_ipv4 {
		packet.extract(hdr.ipv4);

		transition select(hdr.ipv4.protocol) {
			TYPE_TCP: tcp;
			default: accept;
		}
	}

	state tcp {
		packet.extract(hdr.tcp);

		transition accept;
	}
}

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
	apply {}
}

control MyIngress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
	bit<32> reg_pos_syn;
	bit<1> reg_val_syn;
	bit<32> reg_ackno;
	bit<32> reg_pos_conn;
	bit<1> reg_val_conn;

	action reset_flags() {
		hdr.tcp.cwr = 0;
		hdr.tcp.ece = 0;
		hdr.tcp.urg = 0;
		hdr.tcp.ack = 0;
		hdr.tcp.psh = 0;
		hdr.tcp.rst = 0;
		hdr.tcp.syn = 0;
		hdr.tcp.fin = 0;
	}

	action drop() {
		mark_to_drop(standard_metadata);
	}

	action send_back() {
		bit<48> tmpAddr = hdr.ethernet.dstAddr;
		hdr.ethernet.dstAddr = hdr.ethernet.srcAddr;
		hdr.ethernet.srcAddr = tmpAddr;

		standard_metadata.egress_spec = standard_metadata.ingress_port;

		bit<32> tempAddr = hdr.ipv4.srcAddr;
		hdr.ipv4.srcAddr = hdr.ipv4.dstAddr;
		hdr.ipv4.dstAddr = tempAddr;
	}

	action compute_tcp_length() {
		bit<16> tcpLength;
		bit<16> ipv4HeaderLength = ((bit<16>) hdr.ipv4.ihl) * 4;
		tcpLength = hdr.ipv4.totalLen - ipv4HeaderLength;
		meta.tcpLength = ((bit<16>)hdr.tcp.dataOffset) * 4;
		bit<32> payLoadLen = (bit<32>)(hdr.ipv4.totalLen - (ipv4HeaderLength + meta.tcpLength));
		hdr.tcp.ackNo = hdr.tcp.ackNo + payLoadLen;
		hdr.ipv4.hdrChecksum = 0;
		meta.tcpLength = hdr.ipv4.totalLen - ipv4HeaderLength;
	}

	action create_ack_response() {
		reset_flags();

		bit<16> tmp = hdr.tcp.srcPort;
		hdr.tcp.srcPort = hdr.tcp.dstPort;
		hdr.tcp.dstPort = tmp;
		
		hdr.tcp.ack = 1;

		bit<32> seq = hdr.tcp.seqNo;
		hdr.tcp.seqNo = hdr.tcp.ackNo;
		hdr.tcp.ackNo = seq;
	}

	action set_fin() {
		hdr.tcp.fin = 1;
		hdr.tcp.ackNo = hdr.tcp.ackNo + 1;
	}

	action create_syn_ack_response() {
		bit<16> tmpPort = hdr.tcp.dstPort;

		hdr.tcp.dstPort = hdr.tcp.srcPort;
		hdr.tcp.srcPort = tmpPort;

		hdr.tcp.syn = 1;
		hdr.tcp.ack = 1;
		bit<32> seqNo = hdr.tcp.seqNo;
		hdr.tcp.ackNo = hdr.tcp.seqNo + 1;

		hdr.tcp.seqNo = seqNo + 100;
		hdr.tcp.window = hdr.tcp.window + 100;
	}

	apply {
		if (hdr.ipv4.isValid() && hdr.tcp.isValid()) {
			if (hdr.tcp.psh == 1) {
				create_ack_response();
			}
			else if (hdr.tcp.fin == 1) {
				create_ack_response();
				set_fin();
			}
			else if (hdr.tcp.syn == 1 && hdr.tcp.ack == 0) { 
			   create_syn_ack_response();
			}
			else if (hdr.tcp.psh != 1 && hdr.tcp.fin != 1 && hdr.tcp.ack == 1) {
				return;
			}
		}

		if (hdr.ipv4.isValid()) {
			send_back();
		}

		compute_tcp_length();
	}
}

control MyEgress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
	apply {}
}

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
	apply {
		update_checksum(
			hdr.ipv4.isValid(),
			{
				hdr.ipv4.version,
				hdr.ipv4.ihl,
				hdr.ipv4.diffserv,
				hdr.ipv4.totalLen,
				hdr.ipv4.identification,
				hdr.ipv4.flags,
				hdr.ipv4.fragOffset,
				hdr.ipv4.ttl,
				hdr.ipv4.protocol,
				hdr.ipv4.srcAddr,
				hdr.ipv4.dstAddr
			},
			hdr.ipv4.hdrChecksum,
			HashAlgorithm.csum16
		);

		update_checksum_with_payload(
			hdr.tcp.isValid() && hdr.ipv4.isValid(),
			{
				hdr.ipv4.srcAddr,
				hdr.ipv4.dstAddr,
				8w0,
				hdr.ipv4.protocol,
				meta.tcpLength,
				hdr.tcp.srcPort,
				hdr.tcp.dstPort,
				hdr.tcp.seqNo,
				hdr.tcp.ackNo,
				hdr.tcp.dataOffset,
				hdr.tcp.res,
				hdr.tcp.cwr,
				hdr.tcp.ece,
				hdr.tcp.urg,
				hdr.tcp.ack,
				hdr.tcp.psh,
				hdr.tcp.rst,
				hdr.tcp.syn,
				hdr.tcp.fin,
				hdr.tcp.window,
				hdr.tcp.urgentPtr
			},
			hdr.tcp.checksum,
			HashAlgorithm.csum16
		);
	}
}

control MyDeparser(packet_out packet, in headers hdr) {
	apply {
		packet.emit(hdr.ethernet);
		packet.emit(hdr.ipv4);
		packet.emit(hdr.tcp);
	}
}

V1Switch(
	MyParser(),
	MyVerifyChecksum(),
	MyIngress(),
	MyEgress(),
	MyComputeChecksum(),
	MyDeparser()
) main;