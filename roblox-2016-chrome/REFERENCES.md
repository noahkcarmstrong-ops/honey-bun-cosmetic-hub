# Restoration references and asset sources

Target: the blue-header desktop site of 2016. Early and late 2016 layouts differed; these references guide individual pieces rather than proving every current page matches an archived screenshot.

- https://www.webdesignmuseum.org/gallery/roblox-in-2016 — period landing-page screenshot. This is not a signed-in homepage reference.
- https://web.archive.org/web/20160413051516/https://www.roblox.com/catalog/ — catalog capture linked in a preserved CodePen mirror. The archive itself was unavailable during this work.
- https://web.archive.org/web/20160501164208/roblox.com/games/388168427/ZOMBIE-UNIVERSE-BETA-TEST-SUNDAY — game-page capture linked by the community restoration. The archive itself was unavailable during this work.
- https://github.com/anthony1x6000/ROBLOX2016stylus — community restoration used for layout rules: Source Sans Pro, #e3e3e3 page background, #0074bd header, white panels, 152px game cards with 150px images, #02b757 play buttons, and profile/catalog styling. This is a reconstruction, not original Roblox source. Adapted rules are in era-layout.css; its MIT license and contributor credits are included in THEME-LICENSE.txt.
- https://github.com/anthony1x6000/ROBLOX2016stylus/wiki/Font — the four Latin Source Sans Pro font files were obtained from the linked Google Fonts CDN. Files are bundled unchanged in assets/ with Adobe's SIL Open Font License from https://github.com/adobe-fonts/source-sans/blob/release/LICENSE.md.
- LARPBLOX logo: supplied by the user, cropped to the existing transparent artwork bounds without redrawing it.
- https://developer.chrome.com/docs/extensions/reference/api/i18n#predefined-messages — supported extension-ID substitution in CSS for bundled fonts and logo.

Current Roblox /charts server-rendered markup was checked for #header, #nav-logo-link, .navbar-brand, .rbx-navbar-header and .nav-menu-title. Signed-in pages require further visual checks in the user's browser. Existing modern content and controls are kept; removed Roblox features are not recreated as fake working controls.

## Version 1.2: play button and icons

- Current public game-page markup was checked: the live Foundation play button uses `data-testid="play-button"` and `.btn-common-play-game-lg`. Version 1.1 missed this class. Enabled buttons now use the restoration theme's #02b757 normal color and #3fc679 hover/focus color; disabled controls retain a gray disabled appearance.
- https://images.rbxcdn.com/757f696cbfd2d8fcde61d219cead6a2c-branded_04182018.svg — official surviving pre-2019 R$ sprite. The robux, robux-white, and robux-gray groups were extracted as standalone SVGs without redrawing the paths. Their original fills are retained. This surviving file is dated 2018, rather than being an independently verified 2016 capture. Roblox owns the original artwork.
- https://devforum.roblox.com/t/theres-a-new-robux-icon/391639?page=6 — contemporary 2019 discussion links the old R$ sprite replacement approach.
- The Builders Club helmet was supplied by the user. Its transparent image is bundled locally as builders-club.png.
- Current official Navigation.css references `.icon-regular-roblox-plus` and `.icon-filled-premium`; current StyleGuide.css uses the legacy `.icon-premium-*` and `.icon-robux-*` classes. Matching those icons with CSS covers dynamically loaded cards without scanning or rewriting user text. Generic `.icon-plus` add/expand controls and verified badges are deliberately excluded.
- Local browser checks verified normal/hover play colors, disabled state, 16/28px R$ assets, modern Plus and legacy Premium badges, image badges, and an unaffected generic plus icon. Account membership, prices, purchase labels, and click behavior are unchanged.

Avatar layout (1.3): user-supplied Character Customize screenshot is the visual target. Selector research: https://greasyfork.org/en/scripts/551407-2016-roblox-avatar-customizer-for-rlot/code . Independently written CSS; no third-party script or assets copied from that page.

Submenu research (1.3.7): Roblox's original editor redesign announcement https://about.roblox.com/newsroom/2017/02/avatar-editor-update and native submenu selector evidence from https://greasyfork.org/en/scripts/437246-roblox-2012/code . These are reference facts; new submenu CSS was written independently around the user's supplied visual target.

Home favorites (1.5): documented Roblox favorites endpoint https://create.roblox.com/docs/cloud/reference/domains/games and thumbnail services https://create.roblox.com/docs/cloud/reference/domains/thumbnails . Real universe IDs select game icons; root place IDs select game links.

Quick Play launch format: https://create.roblox.com/docs/production/promotion/deeplinks documents the Roblox /games/start?placeId= web launch route.
# Catalog restoration (1.7)

## Original Limited labels (1.8)

The preserved [April 2016 catalog markup](https://codepen.io/notakenusernamedefinetley/pen/JjLyzyW?anon=true&view=pen) references Roblox's [LIMITED image](https://images.rbxcdn.com/793dc1fd7562307165231ca2b960b19a.png) (70×24) and [LIMITED U image](https://images.rbxcdn.com/d649b9c54a08dcfa76131d123e7d8acc.png) (88×24). These original Roblox UI assets are bundled locally as limited-classic.png and limited-unique-classic.png, preserving their transparent padding. The preserved markup uses a limited-overlay inside the item-image link. The custom Catalog places labels at the thumbnail's lower-left and reuses the same art in the legend; native limited-label icon classes are also replaced. Roblox retains rights to its artwork. Generic modern Collectible items use LIMITED; only an explicit LimitedUnique restriction receives LIMITED U.

- User's supplied screenshot defines the layout and visible filter labels.
- [Roblox Marketplace API queries](https://create.roblox.com/docs/projects/assets/api): category/subcategory mappings, creator and price filters, sorting, cursor pagination, result fields and price states.
- [Roblox Catalog categories](https://catalog.roblox.com/v1/categories): current category identifiers, verified through a live request.
- [Roblox Thumbnails API](https://create.roblox.com/docs/cloud/reference/features/thumbnails): asset and bundle thumbnail endpoints; both were checked against live services.
- [Roblox Marketplace help](https://en.help.roblox.com/hc/en-us/articles/203313300-The-Marketplace): supported filter groups.

Historical dropdown contents were not fully established from primary archived 2016 pages. The implementation retains working modern equivalents rather than pretending retired Builders Club/Tickets filters still exist.

