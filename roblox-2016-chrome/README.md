# Roblox 2016 Classic for Chrome

Version 1.18 adds local Larp character saves in Avatar Editor > Avatars > Creations. With Larp mode on, click the existing Create New Character button, enter a name in the save dialog and save. Larp characters appear beside real outfits in the same grid. Click a character thumbnail to wear its full saved look; its gear menu offers Delete. Saves persist per Roblox account in this browser (up to 12). Native Create New Character / Create New Outfit opens the local save dialog while Larp mode is on. Local saves do not create Roblox account outfits.

Version 1.17 adds a website appearance choice. After reloading the extension and refreshing Roblox, open the Robux menu and choose **Website appearance → Current Roblox** for Roblox's current native layout, or **Classic Roblox (2016)** for the classic theme. Switching reloads the page and is remembered across Roblox tabs. The choice is separate from Larp mode: local currency, collected items, Wear/Remove, avatar previews, Larp names, and game sync remain available in both appearances. The added quick Play button and other 2016 page changes run only in Classic appearance. Your saved Larp account data is preserved.




1. Open **chrome://extensions** in Google Chrome.

2. Turn on **Developer mode** at the top right.

3. Click **Load unpacked**.

4. Select this **roblox-2016-chrome** folder (the folder containing manifest.json).

5. Open Roblox, or refresh your existing Roblox tab.



To turn it off, use the switch on its card at chrome://extensions. Changes to these files require clicking the extension's Reload button and refreshing Roblox.



Version 1.1 adds bundled original Source Sans Pro fonts (300/400/600/700), the user's LARPBLOX artwork in the original home link, classic game-card proportions, sidebar spacing, catalog/profile/avatar panels, and Games/Catalog/Develop/Groups labels. A real username heading gets the old Hello greeting where present. The historical light palette is applied visually even if the account is set to dark mode; the account setting is not changed. Existing Roblox links, search, account controls, purchases and game launching are retained. It also runs after Roblox changes pages without a full reload.



It is a visual restoration in progress, not a verified pixel-for-pixel replica. Modern features remain available. Roblox can change its page structure, which may require selector updates. It does not change the Roblox game client. Signed-in pages still need visual verification in the user's Chrome browser.



Privacy: runs only on https://www.roblox.com/. No analytics or remote executable code. Home and Catalog make read-only requests to Roblox games, catalog, and thumbnail services. Catalog search terms and selected filters are sent to Roblox. No cookies permission, storage permission, or background service. Fonts and logo are loaded from this extension. Only these assets are exposed to Roblox pages through web_accessible_resources. Chrome will describe its ability to change Roblox pages because styling the site requires a content script. This is an independent, unofficial extension.



See REFERENCES.md for research sources and asset attribution, THEME-LICENSE.txt for adapted theme rules, and assets/FONT-LICENSE.txt for fonts.



Version 1.2 fixes the current Foundation play button with the classic green and hover colors, replaces supported modern/legacy Robux icons with original R$ artwork, and replaces Plus/Premium membership icons with the user-supplied Builders Club helmet. These visual changes apply to dynamically loaded icons too. Ordinary add/expand plus signs remain functional. Membership status and prices do not change.



Run the package check with `node check.cjs`.



Version 1.9 styles native item detail pages around the supplied classic purchase-page reference: title, large preview and original limited label, creator/avatar and description, gray purchase panel with green Buy with R$ styling, and favorites. Native React nodes and purchase handlers remain in place; current price, ownership, resale, and availability states are not replaced with sample figures. Cart, reseller links, reports, and preview controls remain native. The screenshot's NEW/remaining/sold figures are not invented for items that do not currently provide them. Layout was checked in a browser sample based on observed native markup; a signed-in purchase was not performed. `node item-check.cjs` checks preservation and repeated updates. `item-layout-check.html` is a clearly labeled sample with example numbers, never used on production pages.



Version 1.7 restores the Catalog search page around the supplied classic reference: six-column items, compact search, category/creator/price/sort/sales/availability menus, legend, and green Buy ROBUX link. Results, prices, thumbnails, and pagination come from Roblox's current Marketplace APIs. Item links open native Roblox detail and purchase pages. Classic Shirts/T-Shirts/Pants map to the current classic-clothing categories. Limited Items uses today's collectibles filter. Builders Club is a historical legend only because that membership no longer exists; no obsolete purchase restriction is simulated. Exact historical dropdown entries were not fully verified against an archived 2016 page. Modern categories such as Emotes remain reachable. API failures and empty results display messages rather than sample items. Back/forward navigation restores query filters; canceled requests cannot overwrite newer results. `node catalog-check.cjs` checks filter queries and prices. For the browser sample, serve this directory and open `/catalog/`; the fixture uses saved public catalog/thumbnail responses, not signed-in account data. Production Roblox pages use live requests. Browser sample checks covered filtering, sorting, pagination, empty results, and six-column layout. Signed-in Chrome verification remains necessary.



Version 1.3 adds the supplied Character Customize reference layout: white editor, flat preview, five-column inventory, smaller thumbnails, blue Wear/Remove labels, and classic typography. Native editor controls and modern categories stay available. Backgrounds rendered inside Roblox's 3D canvas may still require selecting a plain background in the editor. The signed-in avatar page requires verification in Chrome; this is not yet a verified exact replica.



Version 1.3.1 fixes vertically stacked avatar inventory: the character preview and inventory receive explicit desktop columns, and the item grid is attached to the actual card parent, including editor builds with an intermediate list wrapper. Browser checks passed for five columns beside the preview at desktop width and two columns below the preview on narrow screens. avatar-layout-check.html is a sample-content regression page; open it through a local web server to check the layout. Signed-in Roblox still requires verification in Chrome.



Version 1.3.2 extends classic avatar tab styling to the current React nav-tabs and accessible tablist controls: white bar, no rounded gray backing, no tab shadows, and plain category labels. Existing dropdowns and overflow navigation remain usable.



Version 1.3.3 fixes equipped-state labels when Roblox places its equipped marker beside the thumbnail. The blue label follows the native equipped state (Wear / Remove), and avatar selection checkmarks are hidden. Browser sample checks verified equip, remove, and hidden checkmarks. The extension leaves Roblox's own click handlers in charge of changing the avatar.



Version 1.3.4 removes the avatar thumbnail's rounded hover overlay and gray hover backgrounds while retaining the blue Wear/Remove label.



Version 1.3.5 lays out supported avatar category submenus as compact blue horizontal links with wrapping, anchored beneath the main tabs. Space above the inventory is reserved for the submenu instead of drawing category text over item buttons.



Version 1.3.6 corrects sibling versus nested submenu positioning, restores hover/focus visibility for native dropdowns, and removes additional equipped check glyphs and marker pseudo-elements. Signed-in accessory glyphs and category hover behavior still require confirmation on the actual Roblox page.



Version 1.3.7 replaces the conflicting submenu positioning patches with normal-flow native submenu rows. Spacing now applies to actual category list items and text-label spans as well as links. Browser checks passed for Recent, Clothing and Accessories: no label overlap and inventory below the submenu. avatar-submenu-check.html provides a sample regression check; signed-in Roblox still requires confirmation.



Version 1.3.8 removes extension-added avatar outlines and uses circular people thumbnails, including friends rows. Decorative rings embedded in Roblox's thumbnail images cannot be removed with border CSS; those require a separate plain-thumbnail source. Account avatar settings are unchanged.



Version 1.4 adds a home greeting using the real account username and a blue outlined Builders Club style badge beneath it when the signed-in header reports Roblox Plus membership. Subscribe navigation links do not count as membership. The badge is a local visual replacement; account membership is unchanged.



Version 1.5 places Recently Played before My Favorites on Home, using classic square game cards. Native favorites are reused where present; otherwise Roblox favorites and thumbnail APIs supply the real games. API errors and empty lists are shown honestly. home-games-check.cjs verifies the behavior; home-games-layout-check.html is a sample visual check.


Version 1.5.1 measures open avatar submenus and offsets the inventory when native zero-height wrappers would cause overlap. Native leave events are deferred while crossing from the tabs into their submenu, then released after leaving the menu area. Browser interaction fixture avatar-menu-interaction-check.html verified a 12px gap above the inventory and successful Classic Shirts selection after moving from the Clothing tab.


Version 1.5.2 extends avatar menu crossing protection to pointer-leave events as well as mouse events, and tracks the actual hovered tab bar instead of picking a potentially inactive duplicate. A browser pointer-leave fixture passed Clothing to Classic Shirts selection.


Version 1.5.3 follows visible category grids after native replacements, including pages without the avatar-items-container ID and inactive hidden duplicates. It measures submenu option bounds and supplies a solid white stacking layer. The browser category-switch check passed with the inventory 12px below the open menu.


Version 1.5.4 retains open native submenus across the entire editor hover area, including leave handlers on outer tab wrappers. Leaving the editor releases the native close event, while choosing a submenu option leaves its native selection handler in control. The wrapper-close browser fixture passed selection of Classic Shirts.


Version 1.6 adds green Play links on game-card hover or keyboard focus. Each uses the card's real place ID and Roblox's documented /games/start?placeId= launch route. Chrome and Roblox retain control of their normal app-open prompts and eligibility checks. Browser fixture verified hidden/revealed state, classic green, and navigation to the correct place launch URL; an actual signed-in game launch was not performed.



Version 1.10 adds Larpbux, a separate pretend currency and cosmetic collection. Open the top-right Robux dropdown, enable Larp mode, and enter a whole-number pretend balance, then click Save. The top-right number shows the pretend balance while enabled; switching off restores the latest real balance. Larp inventory is available from the same dropdown. Item detail pages display the pretend cost before collection. Real items and native inventory remain available; cosmetic collection never grants real ownership. Added accessories preserve existing accessories; classic shirts/pants replace only their respective clothing slot. Bundles and other unsupported types are collection only.

Balance, mode, collection, and outfit selections are saved per Roblox account in www.roblox.com localStorage. Refreshing does not clear this data; clearing site data does. The extension reads public item metadata from economy.roblox.com and catalog.roblox.com. It does not send purchase requests or the cosmetic collection to these services.

Game outfits require manually copying the export into the updated Larpblox script under Accessories > Browser cosmetic outfit. The new browser_outfit.lua and loader.lua are local source changes and must be deployed together before the GitHub launcher can use them. Imported cosmetics are visible locally and use existing Larpblox saved settings. Browser outfit removal changes the export; remove previously imported cosmetics using the game's existing cosmetic controls. No live signed-in Chrome purchase or Roblox runtime was tested. Run node larpbux-check.cjs for balance, additive accessory, clothing-slot, and export checks.

Version 1.10.1 moves Larp mode and the balance control into the native Robux dropdown and removes the floating launcher. Only the local displayed balance changes. The real account balance is never modified. The dropdown check covers persistence, account separation, and restoring native balance updates. larpbux-dropdown-check.html is a local sample page.

Version 1.10.2 removes the extra header label and formats the local balance in the classic Roblox pattern: commas below 10,000, then whole K+/M+/B+ units rounded down. The edit box retains the full amount. This follows the reproduced classic Roblox.NumberFormatting algorithm, not a verified current website bundle; current public bundles did not expose that symbol. Very large values continue using B+ as in that classic algorithm.

Formatting research: first-hand balance observations on Roblox Developer Forum (https://devforum.roblox.com/t/understanding-robux-display-order-and-usage-of/2481428 and https://devforum.roblox.com/t/more-detailed-robux-count-for-over-one-million/60991). A historical reproduced Roblox.NumberFormatting.js snippet has 10^4, 10^6 and 10^9 thresholds (https://gist.github.com/zlnnco/773971f0ebd6fbfc594ed87ab619202d). Only its formatting logic was inspected; the surrounding script is not used.

Version 1.11 replaces the collect/equip controls with a green Buy with R$ button and a classic-style Purchase Item dialog: thumbnail, item price, current balance, remaining balance, Buy Now and Cancel. Confirmation saves the purchase before showing Purchase Complete and a View in Inventory link. Price changes require a fresh quote; insufficient balance and save failures cannot complete a purchase. The quote prefers the native displayed resale price over the original catalog price. Metadata errors fall back to visible native details where available.

As of version 1.12, purchased supported cosmetics appear inside the existing Avatar editor grid. The separate Purchased Items block has been removed from Inventory. They also remain accessible from Larp inventory in the Robux dropdown. Wear/Remove controls save the local outfit selections. These are extension-local purchases and outfit choices, not account grants or automatic browser-avatar changes. The existing manual game import is still required for supported cosmetics.

Research used the preserved official Roblox client purchase prompt (https://github.com/Roblox/Core-Scripts/blob/master/CoreScriptsRoot/CoreScripts/PurchasePromptScript2.lua) and historical catalog recreations as references. The client prompt is not the website dialog, and a pixel-exact 2016 website match was not verified. The browser sample confirmed a displayed resale price of 250 (metadata original price 100), a 1,000 to 750 balance change, Cancel without a charge, success navigation to inventory, and persisted item/Wear state after reload. No signed-in Roblox purchase was performed. Run node larpbux-purchase-check.cjs for purchase, quote, persistence and error-state checks. Local purchase fixtures use example data and are not included in the content-script manifest.

Version 1.11.1 fixes intermittent Buy clicks that appeared to do nothing while a remote metadata request stalled. Item name, type, thumbnail, and displayed price now come directly from the visible page when available, so both confirmation and completion avoid that request. Metadata remains a bounded fallback for incomplete pages; the button shows Loading while waiting and prevents repeated pending clicks. The purchase regression test deliberately leaves metadata pending forever, repeatedly cancels/reopens, then confirms and verifies exactly one charge. The same stalled-service scenario passed in the local browser sample.

Version 1.12 moves purchased hats and supported cosmetics into the existing Avatar editor grid, using its classic blue Wear/Remove controls with no extra heading or panel. Current Roblox items remain available. Purchase completion links to Customize Character. Selections persist per account after reload. The Avatar preview requests a read-only render of the real avatar plus local cosmetics; it never writes account avatar ownership or equipment. The existing manual game export/import is still required for in-game outfits.

Checks passed for native-card preservation, no duplicate cards or extra sections, saved Wear/Remove selections, original-accessory preservation, clothing-slot replacement, and mocked successful preview rendering. A local browser fixture verified Wear, saved selection after refresh, and Remove restoring the native preview. Actual signed-in Roblox rendering and a pixel-exact 2016 match remain unverified. Run larpbux-avatar-check.cjs and larpbux-preview-check.cjs for the new checks.

Version 1.12.1 fixes the selected hat not appearing on the Avatar preview. Roblox returns its color palette as bodyColorsPalette; the previous implementation read bodyColors and failed before sending the render request. The regression checks now use the real field name and GET color keys. Both mocked rendering and conversion of live public Roblox avatar/rules responses pass. Signed-in render completion still requires verification in Chrome. This remains a local preview, not Roblox account ownership or automatic equipment in other games.

Version 1.13 replaces the flat Larp-mode preview with an interactive 3D avatar model inside the existing preview area. It requests thumbnailType 3d, loads Roblox's OBJ/MTL/textures, and supports dragging with either mouse button and scroll-wheel zoom. The existing native 2D/3D toggle is respected. Camera view is retained across preview refreshes; Remove restores the native avatar. Arrow keys rotate and +/- zoom when the preview is focused. No new panels or controls are added.

The renderer is bundled locally in larpbux-avatar-3d.js from larpbux-avatar-3d-source.js using Three.js 0.180.0 (MIT; assets/three-LICENSE.txt) and esbuild 0.25.10. No remote JavaScript is loaded. Rebuild with esbuild --bundle --minify --format=iife --global-name=LarpbloxAvatar3D --target=chrome120 after resolving the pinned Three.js imports. The manifest loads the renderer before larpbux.js.

Browser verification used sample OBJ/MTL geometry and a real Roblox CDN texture: drag rotation, wheel zoom, keyboard rotation, textured rendering and error-free console passed. Avatar regression coverage includes 3D request selection, canvas rendering, retained camera view, stale completion disposal, and native 2D mode. Actual signed-in arbitrary-avatar 3D render completion remains unverified here.

Version 1.13.1 applies the bundled Source Sans Pro Regular font directly to Avatar category and submenu labels, overriding the modern site's nested text fonts while preserving icon fonts.

Version 1.13.2 fixes purchased cosmetics leaking into Avatars > Creations and unrelated categories. Items now match their asset type to Hats, classic Shirts/Pants, and accessory subcategories. Recent continues to show supported purchased items; Currently Wearing shows equipped items only. Unknown categories show no injected cards. Visible breadcrumbs and text changes drive category updates. Category and same-grid navigation regression checks pass.

Version 1.13.3 corrects 3D material rendering. Fully transparent diffuse texels use a small alpha cutoff so they cannot block geometry behind them. A diffuse RGBA texture reused as map_d no longer incorrectly reduces opacity using its green color channel; separate opacity maps and explicit material opacity remain supported. Thin accessories render on both sides. Neutral ambient lighting plus a soft directional light are calibrated for modern Three.js Phong lighting, keeping source sRGB textures and opaque dark clothes intact. Material regression tests failed before the fixes and pass afterward. A local layered-model browser check with a real Roblox CDN texture passed with solid dark pants, visible surfaces behind transparent texels, rotation, and no console errors. The exact signed-in outfit shown by the user was not available to verify locally.

Version 1.13.4 adds gentle automatic rotation to the local 3D preview while keeping drag rotation and zoom. Loading a replacement outfit no longer intercepts input to the existing preview. Rotation pauses during dragging and hidden pages; removing the preview cancels its animation.

Version 1.13.5 fixes purchase loading when native prices contain a currency label or use the price container directly. Metadata requests now have a firm eight-second deadline including response parsing, failed cached requests can retry, and interrupted purchases clear stale loading text. Regression checks cover currency-labelled prices with stalled metadata and repeated timeout/retry.

Version 1.13.6 removes additional Phong shine from thumbnail materials, balances neutral front/back illumination, and doubles idle rotation to a 30-second revolution. Frame timing accommodates slower rendering without reducing the rotation speed below 20 frames per second. Native Roblox lighting and speed constants could not be verified; this is a visual adjustment, not a claimed exact match. Material and avatar integration checks pass; browser sample confirms drag interaction.

Version 1.13.7 fixes outfit reconstruction when adding a local cosmetic: reads authenticated /v2/avatar/avatar, maps its precise bodyColor3s to render bodyColors, and preserves existing asset meta rather than discarding version/layer settings. The mapping matches Roblox ItemDetailsThumbnail's public render assembly. No further lighting guesses in this patch. Regression checks preserve the original shirt/pants/accessories, exact RGB colors and metadata when adding a hat. Actual signed-in before/after appearance still needs user verification.

Version 1.13.8 adds Save preview details inside Robux dropdown > Larp inventory. It downloads a local JSON containing the current rendered OBJ, MTL, descriptor, public texture references, avatar render definition and camera view. It includes no cookies, request headers or authentication tokens and sends nothing automatically. This is diagnosis support for the unresolved before/after color mismatch, not a claimed visual fix.

Version 1.13.9 fixes the confirmed color mismatch using the user's captured model: Roblox's texture atlas already contains the correct sleeve, clothing, skin and accessory colors, but Three multiplied those by exported tan/gray/cyan Kd values. Textured materials now use neutral white diffuse color; untextured parts retain their colors. A regression with the exact captured tan Kd fails before the fix and passes after it. The actual captured OBJ/MTL was rendered in-browser to verify white sleeves, dark pants and untinted accessory textures. Avatar controls and earlier material/opacity checks remain intact.

Version 1.13.10 doubles automatic rotation again, from a 30-second to a 15-second revolution, following user comparison with the native preview. The confirmed atlas color fix is retained.

Version 1.14 adds an optional paired localhost outfit connection. Run the local helper, pair both the connected game script and the Robux dropdown, and enable Larp mode. Game cosmetics populate the Avatar editor and existing Wear/Remove buttons send supported cosmetic changes back. Existing collection and wallet remain intact. See CONNECTION-SETUP.md in the connection package. The local connected loader embeds the new sync and clothing code; the published GitHub loader has not been updated. Relay, account isolation, game mocks, clothing persistence and browser sample checks pass; actual Potassium and signed-in Chrome remain unverified.

Version 1.14.1 uses explicit Avatar Wear/Remove text and keeps existing cards during outfit updates. Polling pauses in hidden tabs and refreshes immediately on return. Old game outfits cannot overwrite a browser choice while it is applying (up to 15 seconds). Automated tab-return checks cover stale replies, immediate labels, stable cards and resumed sync after acknowledgement. Live signed-in Chrome focus switching still needs user confirmation.

Version 1.15 mirrors the active local outfit into own-user avatar pictures across the site: home greeting, identified navigation/user-card avatars, own profile headshot/full body and native 3D profile previews. Pictures share a single cached render/capture per outfit. Current-user profile links, user ID markers and scoped own-profile containers prevent modifying other players. Mode-off/account changes restore native images (including responsive image sources) and canvas visibility. Own profile 3D keeps rotation/drag controls. Headshots are locally framed from the same model; exact Roblox headshot framing is not claimed. Lifecycle and browser sample checks verify cached renders, current-user isolation, native update restoration, failed-render recovery and 3D profile overlay restoration. Live signed-in profile markup remains to be checked by the user.

Version 1.15.1 recognizes current Marketplace category labels (including Head Accessories, Hair Accessories and Classic Shirts/Pants) so purchased cosmetics keep their wearable category. Viewing an already-collected item with an unknown type repairs it without charging again. Explicit Free prices open and confirm at zero immediately without waiting for metadata. Regression cases use the reported Diwali Sparkler Headband ID/name/type/95 price and deliberately stalled metadata, plus free hair and classic clothing. The reported purchase prompt was confirmed working by the user before these changes; the original intermittent prompt failure was not reproduced and is not claimed fixed by this category patch.


### 1.15.2 — Recover missing purchased cosmetics

The avatar editor now recovers missing asset categories for previously purchased Larp items directly from Roblox item details. This fixes the purchased Diwali Sparkler Headband being hidden from Recent > Recently Added when its category had not loaded at purchase time. Recovery saves the category without another charge and preserves the current outfit and balance. Failed requests can retry after a minute; up to four run at once. The avatar integration check covers recovery, correct hat category, unchanged balance, and duplicate request prevention.


### 1.15.3 — Remember the browser connection

Pairing now survives helper restarts. The Windows sign-in installer starts the helper quietly, and the updated connected game script reconnects from its saved code, retries while the helper is unavailable, and resets its sync state after a helper restart. Chrome retains its per-account pairing across restarts. Run the game script again after opening Roblox; automatic attachment/execution is not included. Automated checks cover saved-code retry, helper restart recovery, background-worker recreation, and persistent helper codes.


### 1.15.4 — Retry outfit changes until the game confirms

Wear/Remove now retains the latest requested outfit through temporary send failures and prevents an older game snapshot from restoring removed items while the request is pending. Pending changes retry through the existing connection polling. The game applies incoming outfit changes before publishing its next snapshot, so confirmation reflects the new outfit in the same sync cycle. Regression checks cover failed delivery, stale snapshots, recovery, and the game reporting completed removals.


### 1.16.0 — Accessory regions, clothes and movement packs

Added modern accessory label recognition (including Dark Bat Wings back accessories), classic graphic T-shirts, layered clothing types 64–72, eyebrows/eyelashes, and movement animation component assets. AvatarAnimations bundles resolve their components, retain a single selectable pack card, and expand for preview/export/game sync. The connected build includes matching local backends. R15 is required for layered clothing and standard movement packs. Body bundles, dynamic heads, gear and emotes remain outside this change. Checks cover category matching, purchase classification, bundle expansion/merge, attachment regions, classic T-shirt lifecycle, animation component application and relay dispatch across every newly supported type. Live fitting in each game is not verified by these mocked checks.


### 1.16.1 — Restore game sync and recover back categories

The new movement snapshot loop previously read PoseAnimation from HumanoidDescription, which has no such property in Roblox. This stopped every snapshot and consequently prevented game sync. Native property reads now exclude PoseAnimation and guard optional properties. The relay fixture now throws on invalid properties like Roblox does, so this regression is detectable. Purchased asset categories are verified against catalog details even if an older save assigned a nonzero incorrect type. Verified Back categories cannot be overwritten by the game's fallback Hat type. Dark Bat Wings recovery and balance preservation are covered by the avatar check.

### 1.16.2 — Equipped hat thumbnails

The avatar preview now includes hat thumbnails from its effective outfit: normal Roblox hats together with equipped Larp hats, or the connected game outfit. Duplicate IDs appear once, and extra hats are not limited to three slots. Signed-in page positioning still needs visual verification in Chrome.

### 1.16.3 — Retain unconfirmed outfit changes

Browser Wear/Remove changes remain pending in account storage until the game confirms them, including across page reloads. Changes made before the first game snapshot are preserved while previously unseen original items are merged. The connection message distinguishes helper delivery from confirmation by the game. Regression checks cover a rejected publish followed by reload and a stale first game snapshot. These checks do not establish whether a particular asset can load in the user's current game.

### 1.16.4 — Restore the original preview layout

Removed the extra custom hat column introduced in 1.16.2. Equipped Larp items remain in the 3D avatar preview and the existing avatar inventory grid; the native preview layout is retained.

### 1.16.5 — Navigation avatar headshot

Recognizes Roblox's sized avatar-headshot classes, including the top-left navigation avatar. These use the current Larp headshot rather than a full-body thumbnail while active, and restore the native picture when Larp mode is off.

Version 1.16.6 also recognizes the top-right account avatar when Roblox omits its profile link, so it shows your Larp headshot while Larp mode is active.

Version 1.16.7 fixes avatar thumbnail generation for Roblox responses with numeric skin-color IDs and retries failed thumbnail captures without waiting for another page change. The sidebar, profile circle, and header share the same Larp headshot. Browser regression coverage uses actual Chrome, current profile/navigation markup, the saved outfit path, and real WebGL PNG captures; it does not replace signed-in live-page verification.

Version 1.16.8 adds thumbnail loading status and matching-image details to Save preview details. The report also works on Profile without an open editor preview. This is a diagnostic update, not a confirmed fix for the remaining live-page issue.

Version 1.16.9 recognizes the signed-in sidebar self-profile link (/users/profile) and the current ProfilePlatform hero container. Sidebar matching is reproduced from the signed-in diagnostic report; Chrome regression tests cover both current structures and leave other users' profile portraits unchanged.

Version 1.16.10 makes Currently Wearing on your own profile use the effective Larp outfit, including retained originals and current game-synced body assets. Wear/Remove and game outfit changes update the list. Turning Larp mode off or visiting another profile restores the untouched native list.

Version 1.16.11 adds **Larp names** inside the Robux dropdown. Enter a username and display name, click **Save names**, and turn on **Larp mode**. A blank field keeps its real name. **Restore real names** clears both aliases; turning Larp mode off temporarily restores native names. These settings save per account in this browser and affect supported signed-in header/sidebar and own-profile name displays. In-game names remain a separate setting in the game script's Names tab.

Version 1.16.12 uses one **Larp name** in the Robux dropdown. The separate custom display-name field is removed. The sidebar, top-right account label, Home greeting, and supported own-profile labels use that one name while Larp mode is on; real mode restores native names.

Version 1.16.13 sends the browser's single Larp name to the paired game through the local helper, including enabled/off state. The in-game Names tab is removed. Run the updated helper and reload the updated game script; then use only the browser Robux dropdown to set names. The local People menu name matcher recognizes the own-player @username row and leaves other players with the same display name unchanged. Live game confirmation remains necessary for protected Roblox menus.

Version 1.16.14 fixes missed sidebar and top-right Larp names: normalizes absolute Roblox profile links and recognizes the current Foundation sidebar's self-avatar link without depending on legacy navigation IDs. The Chrome fixture reproduces the captured header/sidebar link structure, including missing display-name metadata, and checks that other users, external links, and plain navigation remain unchanged.
