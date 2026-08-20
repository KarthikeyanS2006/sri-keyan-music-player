import 'package:flutter_test/flutter_test.dart';
import 'package:keyan_music/recommendation_ml.dart';

import 'dart:math' as math;

double cosine(List<double> a, List<double> b) {
  final na = vectorNorm(a);
  final nb = vectorNorm(b);
  if (na == 0 || nb == 0) return 0.0;
  return dotProduct(a, b) / (na * nb);
}

void main() {
  group('ImplicitALS', () {
    // Mock implicit data from the Spotify-blueprint example:
    // Users 0-1 love acoustic tracks (0-2), Users 2-3 love upbeat (3-5).
    test('predicts higher preference for user-preferred items (dot product)', () {
      final counts = [
        [15.0, 20.0, 18.0, 0.0, 1.0, 0.0], // User 0: acoustic
        [22.0, 19.0, 25.0, 0.0, 0.0, 2.0], // User 1: acoustic
        [0.0, 1.0, 0.0, 30.0, 28.0, 35.0], // User 2: upbeat
        [1.0, 0.0, 0.0, 25.0, 31.0, 20.0], // User 3: upbeat
        [12.0, 10.0, 0.0, 15.0, 0.0, 0.0], // User 4: mixed
      ];

      // Factors=3 stable on tiny data
      final als = ImplicitALS(factors: 3, iterations: 30, regularization: 0.05, seed: 1);
      final (userF, itemF) = als.fit(counts);

      

      // User 0 should have higher PREDICTED PREFERENCE (dot) for acoustic items
      final u0 = userF[0];
      final u2 = userF[2];

      double maxDot(List<double> v, List<int> items) =>
          items.map((i) => dotProduct(v, itemF[i])).reduce(math.max);

      final u0Adot = maxDot(u0, [0, 1, 2]);
      final u0Bdot = maxDot(u0, [3, 4, 5]);
      final u2Bdot = maxDot(u2, [3, 4, 5]);
      final u2Adot = maxDot(u2, [0, 1, 2]);

      expect(u0Adot, greaterThan(u0Bdot), reason: 'User 0 dot prefers acoustic');
      expect(u2Bdot, greaterThan(u2Adot), reason: 'User 2 dot prefers upbeat');

      // Best item by predicted preference must be from preferred cluster
      final u0Sims = List.generate(6, (i) => dotProduct(u0, itemF[i]));
      final bestU0 = u0Sims.indexOf(u0Sims.reduce(math.max));
      expect(bestU0, lessThan(3), reason: 'User 0 best item is acoustic');

      final u2Sims = List.generate(6, (i) => dotProduct(u2, itemF[i]));
      final bestU2 = u2Sims.indexOf(u2Sims.reduce(math.max));
      expect(bestU2, greaterThanOrEqualTo(3), reason: 'User 2 best item is upbeat');
    });
  });

  group('LSHIndex', () {
    test('returns nearest vectors (exact scan for small sets)', () {
      final idx = LSHIndex(dim: 4, kHyperplanes: 8, seed: 3);
      idx.addItem(0, [1.0, 0.0, 0.0, 0.0]);
      idx.addItem(1, [0.0, 1.0, 0.0, 0.0]);
      idx.addItem(2, [0.0, 0.0, 1.0, 0.0]);

      // Query close to item 0
      final result = idx.query([0.95, 0.1, 0.0, 0.0], 3);
      expect(result.first, 0);

      // Item 0 is the nearest to itself
      final self = idx.query([1.0, 0.0, 0.0, 0.0], 1);
      expect(self.first, 0);
    });

    test('handles zero vectors without NaN (cold-start safety)', () {
      final idx = LSHIndex(dim: 3, seed: 5);
      idx.addItem(0, [0.0, 0.0, 0.0]); // never-played track -> zero ALS segment
      idx.addItem(1, [1.0, 0.0, 0.0]);

      final result = idx.query([1.0, 0.0, 0.0], 2);
      expect(result.first, 1); // content-bearing vector wins
      expect(result.length, 2);
    });
  });

  group('ContextualBanditRanker', () {
    test('applies negative-skip penalty', () {
      final bandit = ContextualBanditRanker(seed: 1);
      bandit.registerSkipSignal(5);
      final scores = {1: 100.0, 5: 90.0};
      final ranked = bandit.rankAndExploit(
        candidateIds: [1, 5],
        baseScores: scores,
        unplayedCatalogIds: {9},
        epsilon: 0.0, // no exploration, deterministic
      );
      // Song 5 is penalized to 45.0, so song 1 must be first.
      expect(ranked.first, 1);
      expect(bandit.isPenalized(5), isTrue);
      expect(bandit.penaltyFor(5), closeTo(0.5, 1e-9));
    });

    test('decays penalties toward no-penalty', () {
      final bandit = ContextualBanditRanker(seed: 2);
      bandit.registerSkipSignal(3);
      bandit.decaySessionPenalties();
      expect(bandit.penaltyFor(3), closeTo(0.55, 1e-9));
    });

    test('interleaves 80/20 exploit/explore pattern', () {
      final bandit = ContextualBanditRanker(seed: 4);
      final ranked = bandit.interleave(
        exploitOrder: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
        exploreOrder: [10, 11, 12, 13, 14, 15, 16, 17, 18, 19],
      );
      expect(ranked.length, 20);
      // First 4 slots are exploitation, 5th is exploration, etc.
      expect(ranked.take(4), containsAllInOrder([0, 1, 2, 3]));
      expect(ranked[4], inInclusiveRange(10, 19));
      expect(ranked.toSet().length, 20);
    });
  });
}