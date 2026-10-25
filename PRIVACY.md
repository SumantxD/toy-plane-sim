# Toy Plane Sim: Privacy Policy

Last updated: 25 October 2026

Toy Plane Sim is a game made by Sumant Tirkey. It has no accounts, no ads, no analytics and no tracking. This page explains the little information the game handles and where it goes.

## What stays on your device

- **Your pilot name** (you can change or delete it in the game), your settings, the looks you equip and a random player ID used to rejoin a match after a dropped connection.
- **A network log** of connection events (no names or messages), kept so you can send it to us if you report a connection problem. It is deleted when you delete the app.

None of this is sent to us.

## What other players see

When you play multiplayer, your device connects directly to the other players in your room (peer-to-peer). They receive:

- your pilot name, your plane and the looks you equip;
- your plane's position and actions during the match, and the preset taunts you send (there is no free-text or voice chat);
- your device's **IP address**, which any direct internet connection exposes to the other side.

Only people you share a room code with (or who are on your Wi-Fi, for LAN games) can join your room.

## Services that help players connect

To connect players across the internet, the game uses:

- **Public MQTT message brokers** ([HiveMQ](https://www.hivemq.com/), [EMQX](https://www.emqx.com/), [Eclipse Mosquitto](https://test.mosquitto.org/)) to pass short connection-setup messages for your room code. These messages contain network details such as IP addresses, but not your name.
- **STUN servers** run by [Google](https://policies.google.com/privacy) and [Cloudflare](https://www.cloudflare.com/privacypolicy/), which tell your device its public IP address.

These services see your IP address while you connect, under their own privacy policies. Once the match starts, the game no longer uses them. If you set up your own relay (TURN) server in Settings, connection traffic may go through it.

## Purchases

In-app purchases are handled entirely by Apple. The game only learns which items you own, to show them. We never see your payment details or Apple ID. Refunds go through Apple.

## Children

The game does not knowingly collect personal information from anyone, including children under 13. The only typed input shared with others is the pilot name; parents can set it, and in-app purchases follow Apple's Ask to Buy and Screen Time settings.

## Deleting your data

Delete the app to remove everything stored on your device. We hold no data about you on any server, so there is nothing else to delete.

## Contact

Questions or requests: open an issue at https://github.com/SumantxD/toy-plane-sim/issues.

If this policy changes, the new version will be posted on this page with a new date.
