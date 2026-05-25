// Central economy tuning for Little City. Tweak the game's feel here.

/// Tokens every brand-new player starts with (play-fuel before any chore).
const int kStartingTokens = 100;

/// City level curve: every this much city-value = one level.
const int kCityValuePerLevel = 100;

/// XP -> tokens conversion: the deliberately-lossy loop guard.
/// 0.5 => 2 XP buys 1 token.
const double kXpToTokenRate = 0.5;

/// Max tokens a player may obtain from XP per calendar day (UTC).
const int kXpToTokenDailyCap = 20;

/// City level for a given total city value (level 1 at value 0).
int cityLevelForValue(int cityValue) => 1 + (cityValue ~/ kCityValuePerLevel);

/// Tokens produced by converting [xp] XP, rounded down, never negative.
int tokensFromXp(int xp) => xp <= 0 ? 0 : (xp * kXpToTokenRate).floor();
