[![Support: Donate](https://img.shields.io/badge/SUPPORT-DONATE-e05d44?style=for-the-badge)](https://pay.cloudtips.ru/p/8f27a17d)

# Portaxi

Download: [CurseForge](https://www.curseforge.com/wow/addons/portaxi)

Portaxi is a taxi board for mage portals and warlock summons in WoW Forever, Classic Era and Burning Crusade Classic Anniversary.

Mages and warlocks go on duty with their own prices. Players see who is available right now, book a trip in two clicks and pay in gold after they arrive. Every trip both sides confirm counts towards the provider's rating, so good mages and warlocks rise to the top.

## For travellers

- **Portals.** A board of capitals of your faction with the mages on duty for each one: price, rating, number of trips and whether the mage is nearby.
- **Summons.** Summoning points where warlocks stand, marked "Boarding" when the ritual helpers are already there.
- **Booking.** Pick a provider and click "Order". If there is no answer within 30 seconds, the next one is offered. Once your order is accepted, the provider's group invite is accepted for you.
- **Arrival and payment.** The addon sees when you arrive and reminds you to pay. Payment goes through the usual trade window, and the addon checks the amount.
- **Rating.** After the trip you rate it with stars and short tags (fast, polite, long wait, pricey). There is no free text.

## For mages and warlocks

- **My run.** Go on duty, set a price for each destination, choose whether buyers pay before or after the trip, and see your reagents.
- **Orders.** An order arrives as a ticket with a sound. Accept it and the buyer is invited at once. A ticket with a button opens the right portal or starts the ritual on the buyer.
- **From chat.** Requests like "WTB port Org" or "need summon BRD" in public chat, in English or Russian, appear in a list with an "Invite" button.
- **Helpers.** Warlocks can mark that ritual helpers are present or call for them in the group.

## Payment

Payment is in gold, through the normal trade window. Portaxi never moves gold by itself: it opens the trade and checks that the amount arrived. By default you pay after the trip. A provider may ask to be paid first, and the board shows it. Paying first is at your own risk.

## How the ratings stay honest

- Only confirmed trips count: the buyer's addon confirms the arrival and the payment, the provider's addon confirms the delivery. Both must agree within 10 minutes. The game server stamps every sender's name, so nobody can confirm or rate on behalf of someone else.
- Only the buyer of a confirmed trip can rate it, within a day.
- The top lists people, not votes: different buyers over 30 days, one trip per buyer and provider a week, the latest rating of each buyer, at least 5 trips and a rating of 4.0. Buyers below level 10 do not count.
- Trips you did not see yourself are learned from other players only when two of them agree and the buyer lists the trip among his own purchases.
- In WoW Forever (EU) the "Report" button sends a complaint to the Portaxi moderator. Banned players disappear from the board and the top.

## Commands

- `/portaxi` or `/ptx`: open the window. The minimap button does the same.
- `/portaxi diag`: open a diagnostic report. Please copy it into your bug report.

## What the addon shares

Portaxi exchanges data with other copies of the addon through a hidden chat channel and whispers, with no external servers.

- **On duty**, every minute and on changes: class, faction, level, zone and subzone, payment mode, helpers mark and your destinations with prices.
- **Orders and answers** go by whisper to one player: destination, price, your level, zone and class.
- **After a trip** both sides send a confirmation to the channel: a trip number, both names, destination, price, amount paid, buyer level and time. Ratings carry stars and tags only.
- **After login** the addon asks other players for the trips of the last 30 days and sends the list of your own purchases of the last month.
- Trips and your purchases are saved on your computer for a month, along with your settings. Nothing is sent inside dungeons, raids and battlegrounds.

## Good to know

- Only players who have Portaxi installed can be found.
- Offers of the other faction are never shown.
- Window language: English or Russian, switched in the window header, independent of the game language.
- This is the first release, made before WoW Forever opened. If something does not work, please send the `/portaxi diag` report.

## На русском

Скачать: [CurseForge](https://www.curseforge.com/wow/addons/portaxi)

Portaxi это табло такси из порталов магов и призывов чернокнижников для WoW Forever, Classic Era и Burning Crusade Classic Anniversary.

Маги и чернокнижники выходят на линию со своими ценами. Игроки видят, кто свободен прямо сейчас, заказывают поездку в два щелчка и платят золотом по прибытии. Каждая поездка, которую подтвердили обе стороны, идёт в рейтинг перевозчика, поэтому хорошие маги и чернокнижники поднимаются в топ.

**Пассажирам**

- Порталы: столицы своей фракции и маги на линии к каждой, с ценой, рейтингом, числом поездок и пометкой "рядом".
- Призыв: точки, где стоят чернокнижники; пометка "Посадка", когда помощники для ритуала уже на месте.
- Заказ: выберите перевозчика и нажмите "Заказать". Если ответа нет 30 секунд, аддон предложит следующего. Когда заказ принят, приглашение в группу от перевозчика принимается само.
- Прибытие и оплата: аддон видит, что вы прибыли, и напоминает об оплате. Оплата идёт через обычное окно обмена, аддон сверяет сумму.
- Оценка: после поездки звёзды и короткие метки (быстро, вежливо, долго ждал, дорого), без своего текста.

**Магам и чернокнижникам**

- "Мой рейс": выход на линию, цена на каждое направление, оплата до или после поездки, запас реагентов.
- Заказы приходят билетом со звуком. После "Принять" покупатель сразу получает приглашение. Кнопка на билете открывает нужный портал или начинает ритуал на покупателе.
- Просьбы из обычного чата ("WTB port Org", "суммон в БРД", на русском и английском) попадают в список с кнопкой "Пригласить".
- Чернокнижник отмечает, что помощники на месте, или зовёт их в группе.

**Оплата.** Только золотом, через обычное окно обмена. Сам аддон золото не переводит: он открывает обмен и проверяет, что сумма пришла. По умолчанию платят после поездки. Перевозчик может попросить оплату вперёд, табло это показывает. Платить вперёд вы решаете на свой риск.

**Честный рейтинг.** Засчитываются только подтверждённые поездки: аддон покупателя подтверждает прибытие и оплату, аддон перевозчика подтверждает доставку, оба в пределах 10 минут. Имя отправителя ставит сервер игры, поэтому подтвердить или оценить поездку за другого нельзя. Оценить поездку может только её покупатель, в течение суток. В топе считаются люди, а не оценки: разные покупатели за 30 дней, одна поездка пары покупатель и перевозчик в неделю, последняя оценка каждого покупателя, не меньше 5 поездок и оценка от 4,0; покупатели ниже 10 уровня не считаются. Поездки, которые вы не видели сами, принимаются со слов других игроков, только когда двое из них согласны и покупатель сам указал поездку среди своих покупок. В WoW Forever (EU) кнопка "Пожаловаться" отправляет жалобу модератору Portaxi, забаненные пропадают с табло и из топа.

**Команды:** `/portaxi` или `/ptx` открывает окно, кнопка у миникарты делает то же; `/portaxi diag` открывает отчёт для сообщения об ошибке.

**Что передаётся.** Обмен идёт через скрытый канал чата и шёпот, без внешних серверов. На линии раз в минуту и при изменениях: класс, фракция, уровень, зона и подзона, способ оплаты, пометка о помощниках, направления с ценами. Заказы и ответы идут шёпотом одному игроку: направление, цена, ваш уровень, зона и класс. После поездки обе стороны отправляют в канал подтверждение: номер поездки, оба имени, направление, цену, оплаченную сумму, уровень покупателя и время; в оценке только звёзды и метки. После входа аддон спрашивает у других игроков поездки за 30 дней и отправляет список ваших покупок за месяц. Поездки и ваши покупки хранятся на вашем компьютере месяц, там же настройки. В подземельях, рейдах и на полях боя аддон молчит.

**Полезно знать:** найти можно только игроков, у которых стоит Portaxi. Предложения другой фракции не показываются. Язык окна, английский или русский, переключается в заголовке окна и не зависит от языка игры. Это первый выпуск, сделанный до открытия WoW Forever: если что-то не работает, пришлите отчёт `/portaxi diag`.

## License

Copyright (c) 2026 MRAktiv. All rights reserved, see [LICENSE](LICENSE). The libraries in `Libs` belong to their authors and keep their own licenses.

The fonts in `Media/Fonts` keep the SIL Open Font License, see [OFL.txt](Media/Fonts/OFL.txt).
