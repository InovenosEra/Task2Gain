import 'package:flutter_test/flutter_test.dart';
import 'package:task2play/game/economy_config.dart';

void main() {
  test('starting tokens is 100', () {
    expect(kStartingTokens, 100);
  });

  test('city level rises one per kCityValuePerLevel of value', () {
    expect(cityLevelForValue(0), 1);
    expect(cityLevelForValue(kCityValuePerLevel - 1), 1);
    expect(cityLevelForValue(kCityValuePerLevel), 2);
    expect(cityLevelForValue(kCityValuePerLevel * 3), 4);
  });

  test('xp converts to tokens at the lossy rate, rounded down', () {
    expect(tokensFromXp(0), 0);
    expect(tokensFromXp(1), 0);
    expect(tokensFromXp(2), 1);
    expect(tokensFromXp(5), 2);
  });

  test('negative xp never yields tokens', () {
    expect(tokensFromXp(-5), 0);
    expect(tokensFromXp(-1), 0);
  });

  test('daily reward is a positive token amount', () {
    expect(kDailyRewardTokens, greaterThan(0));
  });
}
