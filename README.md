# qm4il-cli

QM4IL persistent email API shell client. 

A minimal shell client for the QM4IL persistent email API — a simple, terminal-based way to receive, parse, and send messages programmatically using the QM4IL SaaS service.

QM4IL offers programmatic access to your inboxes through a simple API. It's ideal for automating flows that involve receiving or validating emails — from testing user signups to running production bots like Bookish Bot's Ryanair account creator.

[API Reference](https://docs.qm4il.com)

## Features

- Send messages via QM4IL's persistent email API from the terminal
- Pure Bash using `curl` and `jq`
- Lightweight and dependency-free

## Requirements

- Bash
- curl
- jq

## Usage

Clone the repo and source the script in your shell:

```bash
git clone https://github.com/ql4biz/qm4il-cli.git
cd qm4il-cli
source qm4il.sh
```

To configure your credentials, run:

```bash
Qm4ilInitConfig
```

This will create a `.qm4ilrc` file in your home directory with your API key, default inbox ID, and the API endpoint. You can edit this file anytime or override the values in your shell session.

You can then use the built-in functions:

```bash
Qm4ilSend "hello@qm4il.com" "Your message here"
Qm4ilSendFortune "hello@qm4il.com"
```

> `Qm4ilSendFortune` sends a random fortune using the Unix `fortune` command (optional).

> `Qm4ilReceiveUnreadMessage` returns a single unread message from the inbox, if available. If no unread messages exist, it returns a 404 response.

## API Reference

For full API details and request structure, visit the [QM4IL API Reference](https://docs.qm4il.com/reference).

## License

MIT
