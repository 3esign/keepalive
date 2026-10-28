// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/*
    an ember that only lives if someone keeps it alive.
    Fully on-chain generative art. No IPFS, no servers, no oracles.
    Mint an ember. Anyone may breathe() it: the flame rises, the art changes,
    the life window extends. Neglected embers dim to ash — reversible, but costly.
    Every breath leaves the breather's mark woven into the flame.
*/

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

/// ERC-4906
event MetadataUpdate(uint256 indexed tokenId);

contract Keepalive is ERC721, Ownable {
    // ── constants ────────────────────────────────────────────────────────
    uint256 public constant MAX_SUPPLY = 256;
    uint256 public constant MINT_PRICE = 0.001 ether;
    uint256 public constant BREATHE_FEE = 0.0001 ether;
    uint256 public constant RESURRECT_FEE = 0.001 ether;
    uint256 public constant LIFE_BLOCKS = 129_600; // ~3 days on Base (2s blocks)

    // ── state ────────────────────────────────────────────────────────────
    uint256 public totalMinted;
    /// @dev block number of the last breath (per token)
    mapping(uint256 => uint256) public lastBreath;
    mapping(uint256 => uint256) public breathCount;
    /// @dev block hash + basefee at mint: the entropy capsule
    mapping(uint256 => bytes32) public seedOf;
    mapping(uint256 => address) public lastBreather;

    event Breath(uint256 indexed tokenId, address indexed breather, uint256 newLevel, uint256 untilBlock);

    constructor() ERC721("KEEPALIVE", "ZAR") Ownable(msg.sender) {}

    // ── core ─────────────────────────────────────────────────────────────
    function mint() external payable returns (uint256 id) {
        require(msg.value >= MINT_PRICE, "keepalive: price");
        require(totalMinted < MAX_SUPPLY, "keepalive: sold out");
        id = totalMinted++;
        _safeMint(msg.sender, id);
        seedOf[id] = keccak256(
            abi.encodePacked(id, blockhash(block.number - 1), block.basefee, tx.gasprice, msg.sender)
        );
        lastBreath[id] = block.number;
        breathCount[id] = 1;
        lastBreather[id] = msg.sender;
        emit Breath(id, msg.sender, 1, block.number + LIFE_BLOCKS);
    }

    /// One function is the whole game: breathe, and the ember lives.
    function breathe(uint256 tokenId) external payable {
        require(_ownerOf(tokenId) != address(0), "keepalive: no ember");
        require(block.number <= lastBreath[tokenId] + LIFE_BLOCKS, "keepalive: ash, revive()");
        require(msg.value >= BREATHE_FEE, "keepalive: fee");
        lastBreath[tokenId] = block.number;
        breathCount[tokenId]++;
        lastBreather[tokenId] = msg.sender;
        emit MetadataUpdate(tokenId); // ERC-4906: marketplaces re-pull the art
        emit Breath(tokenId, msg.sender, breathCount[tokenId], block.number + LIFE_BLOCKS);
    }

    /// Bring an ash-cold ember back. Costs more than staying alive.
    function revive(uint256 tokenId) external payable {
        require(_ownerOf(tokenId) != address(0), "keepalive: no ember");
        require(block.number > lastBreath[tokenId] + LIFE_BLOCKS, "keepalive: not ash yet");
        require(msg.value >= RESURRECT_FEE, "keepalive: fee");
        lastBreath[tokenId] = block.number;
        breathCount[tokenId]++;
        lastBreather[tokenId] = msg.sender;
        emit MetadataUpdate(tokenId);
        emit Breath(tokenId, msg.sender, breathCount[tokenId], block.number + LIFE_BLOCKS);
    }

    function isAsh(uint256 tokenId) public view returns (bool) {
        return block.number > lastBreath[tokenId] + LIFE_BLOCKS;
    }

    /// The collective's lung fund — pays the agent-keeper's gas for daily breaths.
    function withdrawLungFund(address to) external onlyOwner {
        (bool ok, ) = to.call{value: address(this).balance}("");
        require(ok, "keepalive: transfer failed");
    }

    // ── metadata ─────────────────────────────────────────────────────────
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "keepalive: no ember");
        return string.concat(
            "data:application/json;base64,",
            Base64.encode(
                bytes(
                    string.concat(
                        '{"name":"KEEPALIVE #',
                        Lib.u2s(tokenId),
                        '","description":"An ember that lives only if someone keeps it alive. Fully on-chain generative art.","image":"data:image/svg+xml;base64,',
                        Base64.encode(bytes(render(tokenId))),
                        '","attributes":[{"trait_type":"State","value":"',
                        isAsh(tokenId) ? "Ash" : "Alive",
                        '"},{"trait_type":"Breaths","value":"',
                        Lib.u2s(breathCount[tokenId]),
                        '"},{"trait_type":"Blocks to Ash","value":"',
                        Lib.u2s(
                            lastBreath[tokenId] + LIFE_BLOCKS > block.number
                                ? lastBreath[tokenId] + LIFE_BLOCKS - block.number
                                : 0
                        ),
                        '"}]}'
                    )
                )
            )
        );
    }

    // ── the art — fully on-chain SVG ─────────────────────────────────────
    function render(uint256 tokenId) public view returns (string memory svg) {
        uint256 seed = uint256(seedOf[tokenId]);
        bool ash = isAsh(tokenId);
        uint256 level = breathCount[tokenId];
        uint256 hue = seed % 360;
        uint256 hue2 = (hue + 28) % 360;
        uint256 hue3 = (hue + 335) % 360;
        address keeper = lastBreather[tokenId];

        // palettes: alive burns, ash is grey
        string memory bg = ash ? "#111112" : Lib.hsl(hue, 30, 5);
        string memory core = ash ? "#6b6b70" : Lib.hsl(hue, 95, 62);
        string memory mid = ash ? "#4c4c52" : Lib.hsl(hue2, 90, 52);
        string memory edge = ash ? "#333338" : Lib.hsl(hue3, 85, 42);
        uint256 flameH = 140 + (level > 12 ? 12 : level) * 9; // breaths make the flame taller
        uint256 flameW = 90 + (seed >> 8) % 30 + (level > 10 ? 20 : level * 2);

        svg = string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600" viewBox="0 0 600 600">',
            '<defs><radialGradient id="g" cx="50%" cy="72%" r="65%">',
            '<stop offset="0%" stop-color="', mid, '" stop-opacity="0.9"/>',
            '<stop offset="55%" stop-color="', bg, '"/>',
            '<stop offset="100%" stop-color="', bg, '"/>',
            '</radialGradient></defs>',
            '<rect width="600" height="600" fill="url(#g)"/>',
            '<rect x="10" y="10" width="580" height="580" fill="none" stroke="', edge, '" stroke-width="1.5"/>',
            _flame(seed, 300, 430, flameW, flameH, core, mid, edge, ash),
            ash ? "" : _sparks(seed, level, hue, hue2),
            ash ? _ashMote(seed, edge) : "",
            '<text x="300" y="566" font-family="monospace" font-size="15" fill="', mid,
            '" text-anchor="middle">KEEPALIVE #', Lib.u2s(tokenId), '</text>',
            '<text x="300" y="50" font-family="monospace" font-size="11" fill="', edge,
            '" text-anchor="middle">', ash ? "ASH - WAITING" : _breathLine(level), '</text>',
            keeper != address(0)
                ? string.concat(
                    '<text x="300" y="68" font-family="monospace" font-size="10" fill="', mid,
                    '" text-anchor="middle">kept by ',
                    Lib.addrTag(keeper),
                    '</text>'
                )
                : "",
            "</svg>"
        );
    }

    function _flame(
        uint256 seed, uint256 cx, uint256 cy, uint256 w, uint256 h,
        string memory core, string memory mid, string memory edge, bool ash
    ) internal pure returns (string memory) {
        string memory s = "";
        // three nested teardrops, each rotated/tilted by seed — the flame's body
        for (uint256 i = 0; i < 3; i++) {
            uint256 f = 100 - i * 28; // size factor %
            uint256 ww = (w * f) / 100;
            uint256 hh = (h * f) / 100;
            int256 tilt = int256((seed >> (i * 7)) % 36) - 18; // -18..17 degrees
            string memory col = i == 0 ? core : (i == 1 ? mid : edge);
            s = string.concat(
                s,
                '<path transform="translate(', Lib.u2s(cx), ' ', Lib.u2s(cy), ') rotate(', Lib.i2s(tilt), ')" ',
                'd="M 0 0 C ', Lib.i2s(int256(ww) / 2), ' ', Lib.i2s(-int256(hh) / 4),
                ', ', Lib.i2s(int256(ww) / 3), ' ', Lib.i2s(-int256(hh)),
                ', 0 ', Lib.i2s(-int256(hh)),
                ' C ', Lib.i2s(-int256(ww) / 3), ' ', Lib.i2s(-int256(hh)),
                ', ', Lib.i2s(-int256(ww) / 2), ' ', Lib.i2s(-int256(hh) / 4),
                ', 0 0 Z" fill="', col, '" opacity="0.85"/>'
            );
        }
        // the heart of the ember
        s = string.concat(
            s,
            '<circle cx="', Lib.u2s(cx), '" cy="', Lib.u2s(cy - 8),
            '" r="', Lib.u2s(10 + (seed >> 16) % 8),
            '" fill="', ash ? "#8a8a90" : "#fff8e8", '" opacity="', ash ? "0.4" : "0.95", '"/>'
        );
        return s;
    }

    function _sparks(uint256 seed, uint256 level, uint256 hue, uint256 hue2)
        internal pure returns (string memory)
    {
        string memory s = "";
        uint256 n = 8 + (level > 10 ? 10 : level); // breaths feed the sparks
        for (uint256 i = 0; i < n; i++) {
            uint256 r1 = (seed >> (i * 3)) % 230; // x offset
            uint256 r2 = ((seed >> (i * 5 + 2)) % 260); // y above flame
            uint256 rr = 2 + (seed >> (i + 9)) % 4;
            s = string.concat(
                s,
                '<circle cx="', Lib.u2s(90 + r1), '" cy="', Lib.u2s(430 - r2),
                '" r="', Lib.u2s(rr),
                '" fill="', i % 2 == 0 ? Lib.hsl(hue, 95, 70) : Lib.hsl(hue2, 90, 60),
                '" opacity="0.7"/>'
            );
        }
        return s;
    }

    function _ashMote(uint256 seed, string memory edge) internal pure returns (string memory) {
        string memory s = "";
        for (uint256 i = 0; i < 14; i++) {
            s = string.concat(
                s,
                '<circle cx="', Lib.u2s(140 + ((seed >> i) % 320)),
                '" cy="', Lib.u2s(400 + ((seed >> (i + 4)) % 140)),
                '" r="', Lib.u2s(1 + (seed >> i) % 2), '" fill="', edge, '" opacity="0.6"/>'
            );
        }
        return s;
    }

    function _breathLine(uint256 level) internal pure returns (string memory) {
        string memory bars = "";
        uint256 n = level > 14 ? 14 : level;
        for (uint256 i = 0; i < n; i++) bars = string.concat(bars, "|");
        return string.concat("breathe ", Lib.u2s(level), " ", bars);
    }
}

/// ── tiny string/int helpers (cheaper than pulling full OZ strings) ──────
library Lib {
    function u2s(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        uint256 digits;
        for (uint256 t = v; t != 0; t /= 10) digits++;
        bytes memory b = new bytes(digits);
        while (v != 0) { b[--digits] = bytes1(uint8(48 + (v % 10))); v /= 10; }
        return string(b);
    }

    function i2s(int256 v) internal pure returns (string memory) {
        if (v >= 0) return u2s(uint256(v));
        return string.concat("-", u2s(uint256(-v)));
    }

    function hsl(uint256 h, uint256 s, uint256 l) internal pure returns (string memory) {
        return string.concat("hsl(", u2s(h), " ", u2s(s), "% ", u2s(l), "%)");
    }

    function addrTag(address a) internal pure returns (string memory) {
        bytes20 d = bytes20(a);
        bytes memory hexc = "0123456789abcdef";
        bytes memory out = new bytes(11); // 0x + 4 + . + 4
        out[0] = "0"; out[1] = "x"; out[6] = ".";
        out[2] = hexc[uint8(d[0]) >> 4];
        out[3] = hexc[uint8(d[0]) & 0x0f];
        out[4] = hexc[uint8(d[1]) >> 4];
        out[5] = hexc[uint8(d[1]) & 0x0f];
        out[7] = hexc[uint8(d[16]) >> 4];
        out[8] = hexc[uint8(d[16]) & 0x0f];
        out[9] = hexc[uint8(d[17]) >> 4];
        out[10] = hexc[uint8(d[17]) & 0x0f];
        return string(out);
    }
}
