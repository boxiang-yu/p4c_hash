#include <ebpf_model.p4>
#include <core.p4>

#include "ebpf_headers.p4"

struct Headers_t {
    Ethernet_h ethernet;
    IPv4_h     ipv4;
}

parser prs(packet_in p, out Headers_t headers) {
    state start {
        p.extract(headers.ethernet);
        transition select(headers.ethernet.etherType, 16w1) {
            (default, 16w1) : ip;
            default : reject;
        }
    }

    state ip {
        p.extract(headers.ipv4);
        transition accept;
    }
}

control pipe(inout Headers_t headers, out bool pass) {
    action invalidate() {
        headers.ipv4.setInvalid();
        headers.ethernet.setInvalid();
        pass = true;
    }
    action drop() {
        pass = false;
    }
    table t {
        key = {
            headers.ipv4.srcAddr : exact;
            headers.ipv4.dstAddr : exact;
            headers.ethernet.dstAddr : exact;
            headers.ethernet.srcAddr: exact;
        }
        actions = {
            invalidate; drop;
        }
        implementation = hash_table(10);
        default_action = drop;
    }

    apply {
        t.apply();
    }
}

ebpfFilter(prs(), pipe()) main;
