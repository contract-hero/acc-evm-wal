# /acc-evm-wal:start

Start a lesson in **acc-evm-wal**.

Welcome! This short course teaches the basics of [Walrus](https://www.walrus.xyz/) decentralized storage and how to wire it into a Solidity smart contract. You'll learn how Walrus blob IDs work, the off-chain HTTP API for storing and reading blobs, and the on-chain pattern of persisting a blob ID inside an EVM contract so any dApp can retrieve the associated content later. By the end you'll have a working Foundry project where a Solidity contract anchors a Walrus-hosted asset on-chain.

To begin, invoke ACC's `course-engine` skill (from the `agentic-community-college` plugin) with a course filter pinned to `acc-evm-wal` — that will list only this course's lessons, walk the learner through selection, run the picked lesson's prerequisite probes, collect output mode (learning vs explanatory) and personalization, and hand off to the `course-conductor` agent for the section loop.

If `agentic-community-college` isn't enabled, the user needs to install it first (e.g. `claude plugins install agentic-community-college@<marketplace>`); this start command is a thin wrapper that depends on the framework.
