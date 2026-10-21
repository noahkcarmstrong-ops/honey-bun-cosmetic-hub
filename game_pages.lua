-- Add game pages here; page implementations are loaded on first use.
return {
    {id="MM2",label="MM2",source="mm2_page.lua",matches=function(game)
        return game.GameId==66654135 or game.PlaceId==142823291
    end},
}
