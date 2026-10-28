# KEEPALIVE — skill.md

Use this skill for interacting with the KEEPALIVE collection: a fully on-chain
generative NFT on Base where tokens expire unless someone calls `breathe()`.

## Contract
- **Address (live, Base mainnet): `0x47B27513F9Fea27A4C3cDaA12F758fE054518678`**
  (deploy tx `0x593e93c718435fb788d53c78be1710a468f485570b7c04b93b4ee3ed6f60be20`)
- Name/symbol: **KEEPALIVE / ZAR** (ERC-721 + ERC-4906 metadata updates)
- Deploy target: **Base mainnet**
- Supply: 256 · Mint 0.001 ETH · breathe() 0.0001 ETH · revive() 0.001 ETH
- Life window: 129,600 blocks per breath (~3 days on Base, 2s blocks)
- State: `lastBreath(uint256)`, `breathCount(uint256)`, `lastBreather(uint256)`,
  `isAsh(uint256) view returns (bool)`
- Art: `tokenURI(uint256)` returns a base64 data URI whose image is an SVG
  rendered **inside the contract**. No IPFS, no server.

## Tasks you can do for a user

1. **Mint** — call `mint()` with 0.001 ETH.
2. **Breathe** — call `breathe(tokenId)` with 0.0001 ETH. Works on *anyone's*
   token within its life window. This is the stewardship game: strangers' gas
   keeps the collection alive.
3. **Revive** — if `isAsh(tokenId)` is true, `breathe()` reverts; call
   `revive(tokenId)` with 0.001 ETH instead.
4. **Check health** — read `isAsh`, `breathCount`, `lastBreath + 129600` vs
   current block. Report "blocks to ash".
5. **Render/view art** — fetch `tokenURI(tokenId)`, base64-decode the JSON,
   decode the `image` field as SVG.

## Keeper routine (for the collection's agent-keeper)

Daily (or every ~40k blocks):
1. For each token in 0..255: if `ownerOf` is non-zero AND `isAsh` is false AND
   `block.number > lastBreath + 100_000` (safety margin), call `breathe(id)`.
2. If `isAsh` and the token is culturally significant (early token, high
   breathCount), surface it to the human — revival is a decision, not a reflex.
3. Fund source: the contract's `withdrawLungFund` (owner-only) covers the gas —
   breath fees accumulate there as "the collective's lung fund".

## Notes
- Every `breathe`/`revive` emits ERC-4906 `MetadataUpdate` — marketplaces
  re-pull art automatically.
- The art mutates with state: breaths raise the flame and multiply sparks,
  `lastBreather`'s address tag is printed in the smoke, ash greys everything.
- One tweet launch recipe: deploy contract → verify on Basescan → mint #1 →
  tweet the collection with the site link; users can breathe via the agent.
