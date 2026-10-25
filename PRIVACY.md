# Toy Plane Arcade: Privacy Policy

Last updated: 26 October 2026

Toy Plane Arcade is a game made by Sumant Tirkey. It has no accounts, no ads, no analytics and no tracking. This page explains the little information the game handles and where it goes.

## What stays on your device

- **Your pilot name** (you can change or delete it in the game), your settings, the looks you equip and a random player ID used to rejoin a match after a dropped connection.
- **A network log** of connection events, such as players joining and leaving, including their pilot names and IP addresses. It is used to diagnose connection problems, stays on your device, and is deleted when you delete the app.

None of this is sent to us.

## What other players see

When you play multiplayer, your device connects directly to the other players in your room (peer-to-peer). They receive:

- your pilot name, your plane and the looks you equip;
- your plane's position and actions during the match, and the preset taunts you send (there is no free-text or voice chat);
- your device's **IP address**, which any direct internet connection exposes to the other side;
- your random player ID (sent to the host only), so you can rejoin the match if your connection drops.

Only people you share a room code with (or who are on your Wi-Fi, for LAN games) can join your room.

Pilot names are checked against a filter of offensive words. The host can remove a player from the room. To report a player, email st72365@gmail.com with the pilot name and what happened.

## Services that help players connect

To connect players across the internet, the game uses:

- **Public MQTT message brokers** ([HiveMQ](https://www.hivemq.com/), [EMQX](https://www.emqx.com/), [Eclipse Mosquitto](https://test.mosquitto.org/)) to pass connection-setup messages for your room code. These messages contain network details, including your IP addresses, but not your name. They are sent on public topics named after the room code, so anyone subscribed to that topic can read them.
- **STUN servers** run by [Google](https://policies.google.com/privacy) and [Cloudflare](https://www.cloudflare.com/privacypolicy/), which tell your device its public IP address.

These services see your IP address, under their own privacy policies. A player who joins a room disconnects from the broker once connected. The host stays connected to the broker for as long as the room is open, so new players can join. On the desktop versions only, you can configure your own relay (TURN) server; connection traffic may then go through it.

## Purchases

In-app purchases are handled entirely by Apple. The game only learns which items you own, to show them. We never see your payment details or Apple ID. Refunds go through Apple.

## Children

The game does not knowingly collect personal information from anyone, including children under 13. The only typed input shared with others is the pilot name; parents can set it, and in-app purchases follow Apple's Ask to Buy and Screen Time settings.

## Deleting your data

Delete the app to remove everything stored on your device. We hold no data about you on any server, so there is nothing else to delete.

## Contact

Questions or requests: email st72365@gmail.com, or open an issue at https://github.com/SumantxD/toy-plane-sim/issues.

If this policy changes, the new version will be posted on this page with a new date.
