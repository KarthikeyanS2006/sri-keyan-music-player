import 'dart:math' as math;

import 'package:flutter/foundation.dart' show compute;

// =============================================================
// Core vector math helpers (pure Dart, isolate-safe)
// =============================================================

double dotProduct(List<double> a, List<double> b) {
  double s = 0.0;
  for (int i = 0; i < a.length; i++) {
    s += a[i] * b[i];
  }
  return s;
}

double vectorNorm(List<double> a) => math.sqrt(dotProduct(a, a));

/// Safe L2 normalization. Near-zero vectors become all-zeros so that
/// cosine / angular distance never divides by zero.
List<double> normalizeVector(List<double> vec, {double eps = 1e-9}) {
  double norm = vectorNorm(vec);
  if (norm < eps) return List.filled(vec.length, 0.0);
  return vec.map((v) => v / norm).toList();
}

// =============================================================
// 1. Implicit Matrix Factorization (ALS)
//    min_{u,i} sum c_ui (p_ui - x_u^T y_i)^2 + lambda(||x_u||^2 + ||y_i||^2)
//    p_ui = 1 if r_ui > 0 else 0 ; c_ui = 1 + alpha * r_ui
//    Sparse-optimized: shares Y^T Y / X^T X across all users/items.
// =============================================================

class ALSInputPayload {
  final List<List<double>> interactionMatrix;
  final int factors;
  final int iterations;
  final double regularization;
  final double alpha;

  ALSInputPayload({
    required this.interactionMatrix,
    required this.factors,
    required this.iterations,
    required this.regularization,
    this.alpha = 40.0,
  });
}

class ALSResultPayload {
  final List<List<double>> userFactors;
  final List<List<double>> itemFactors;

  ALSResultPayload({required this.userFactors, required this.itemFactors});
}

/// Top-level pure function so it can be shipped to a background isolate
/// via [compute].
ALSResultPayload runImplicitALSTraining(ALSInputPayload payload) {
  final als = ImplicitALS(
    factors: payload.factors,
    iterations: payload.iterations,
    regularization: payload.regularization,
    alpha: payload.alpha,
  );
  final (userF, itemF) = als.fit(payload.interactionMatrix);
  return ALSResultPayload(userFactors: userF, itemFactors: itemF);
}

class ImplicitALS {
  final int factors;
  final double regularization;
  final int iterations;
  final double alpha;
  final int seed;

  ImplicitALS({
    this.factors = 16,
    this.regularization = 0.05,
    this.iterations = 12,
    this.alpha = 40.0,
    this.seed = 42,
  });

  (List<List<double>>, List<List<double>>) fit(List<List<double>> counts) {
    final numUsers = counts.length;
    final numItems = counts.isNotEmpty ? counts.first.length : 0;
    if (numUsers == 0 || numItems == 0) return (const [], const []);

    final f = factors;
    final rand = math.Random(seed);
    var X = _initFactors(numUsers, f, rand);
    var Y = _initFactors(numItems, f, rand);

    for (var it = 0; it < iterations; it++) {
      X = _solveUsers(Y, counts, numUsers, numItems);
      Y = _solveItems(X, counts, numUsers, numItems);
    }
    return (X, Y);
  }

  List<List<double>> _initFactors(int rows, int f, math.Random rand) {
    return List.generate(
      rows,
      (_) => List.generate(f, (_) => (rand.nextDouble() - 0.5) * 0.1),
    );
  }

  // x_u = (Y^T C^u Y + lambda I)^-1 Y^T C^u p_u
  List<List<double>> _solveUsers(
    List<List<double>> Y,
    List<List<double>> counts,
    int numUsers,
    int numItems,
  ) {
    final f = factors;
    final yTy = List.generate(f, (_) => List<double>.filled(f, 0));
    for (var a = 0; a < f; a++) {
      for (var b = a; b < f; b++) {
        var s = 0.0;
        for (var i = 0; i < numItems; i++) {
          s += Y[i][a] * Y[i][b];
        }
        yTy[a][b] = s;
        yTy[b][a] = s;
      }
    }

    final X = List.generate(numUsers, (_) => List<double>.filled(f, 0));
    for (var u = 0; u < numUsers; u++) {
      final A = List.generate(f, (i) => List<double>.of(yTy[i]));
      final b = List<double>.filled(f, 0);
      for (var i = 0; i < numItems; i++) {
        final r = counts[u][i];
        if (r <= 0) continue;
        final cMinus1 = alpha * r; // (1 + alpha*r) - 1
        final conf = 1.0 + alpha * r;
        final yi = Y[i];
        for (var a = 0; a < f; a++) {
          final ya = yi[a];
          final row = A[a];
          for (var bb = 0; bb < f; bb++) {
            row[bb] += cMinus1 * ya * yi[bb];
          }
          b[a] += conf * ya;
        }
      }
      for (var d = 0; d < f; d++) {
        A[d][d] += regularization;
      }
      X[u] = _solveLinear(A, b);
    }
    return X;
  }

  // y_i = (X^T C^i X + lambda I)^-1 X^T C^i p_i
  List<List<double>> _solveItems(
    List<List<double>> X,
    List<List<double>> counts,
    int numUsers,
    int numItems,
  ) {
    final f = factors;
    final xTx = List.generate(f, (_) => List<double>.filled(f, 0));
    for (var a = 0; a < f; a++) {
      for (var b = a; b < f; b++) {
        var s = 0.0;
        for (var u = 0; u < numUsers; u++) {
          s += X[u][a] * X[u][b];
        }
        xTx[a][b] = s;
        xTx[b][a] = s;
      }
    }

    final Y = List.generate(numItems, (_) => List<double>.filled(f, 0));
    for (var i = 0; i < numItems; i++) {
      final A = List.generate(f, (r) => List<double>.of(xTx[r]));
      final b = List<double>.filled(f, 0);
      for (var u = 0; u < numUsers; u++) {
        final r = counts[u][i];
        if (r <= 0) continue;
        final cMinus1 = alpha * r;
        final conf = 1.0 + alpha * r;
        final xu = X[u];
        for (var a = 0; a < f; a++) {
          final xa = xu[a];
          final row = A[a];
          for (var bb = 0; bb < f; bb++) {
            row[bb] += cMinus1 * xa * xu[bb];
          }
          b[a] += conf * xa;
        }
      }
      for (var d = 0; d < f; d++) {
        A[d][d] += regularization;
      }
      Y[i] = _solveLinear(A, b);
    }
    return Y;
  }

  // Gaussian elimination with partial pivoting: solves A x = b
  List<double> _solveLinear(List<List<double>> A, List<double> b) {
    final n = b.length;
    final M = List.generate(n, (i) => List<double>.of(A[i]));
    final v = List<double>.of(b);

    for (var col = 0; col < n; col++) {
      var pivot = col;
      var maxAbs = M[col][col].abs();
      for (var r = col + 1; r < n; r++) {
        final a = M[r][col].abs();
        if (a > maxAbs) {
          maxAbs = a;
          pivot = r;
        }
      }
      if (maxAbs < 1e-12) return List<double>.filled(n, 0);
      if (pivot != col) {
        final tmpR = M[col];
        M[col] = M[pivot];
        M[pivot] = tmpR;
        final tmpV = v[col];
        v[col] = v[pivot];
        v[pivot] = tmpV;
      }
      final diag = M[col][col];
      for (var c = col; c < n; c++) {
        M[col][c] /= diag;
      }
      v[col] /= diag;
      for (var r = 0; r < n; r++) {
        if (r == col) continue;
        final factor = M[r][col];
        if (factor.abs() < 1e-12) continue;
        for (var c = col; c < n; c++) {
          M[r][c] -= factor * M[col][c];
        }
        v[r] -= factor * v[col];
      }
    }
    return v;
  }
}

// =============================================================
// 2. Approximate Nearest Neighbors via Random Projection LSH
//    (Annoy-style). Exact brute-force scan below 256 items for
//    100% recall; multi-probe LSH above that threshold.
// =============================================================

class LSHIndex {
  final int dim;
  final int kHyperplanes;
  late final List<List<double>> _hyperplanes;
  final Map<int, List<int>> _buckets = {}; // bitmask key -> item ids
  final Map<int, List<double>> _itemVectors = {};
  final math.Random _rand;

  LSHIndex({required this.dim, this.kHyperplanes = 16, int? seed})
      : _rand = math.Random(seed ?? 42) {
    _hyperplanes = List.generate(
      kHyperplanes,
      (_) => List.generate(dim, (_) => _gaussianRandom(_rand)),
    );
  }

  // Box-Muller transform for standard normal N(0,1)
  double _gaussianRandom(math.Random rand) {
    double u1 = rand.nextDouble();
    double u2 = rand.nextDouble();
    while (u1 <= 1e-15) {
      u1 = rand.nextDouble();
    }
    return math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2);
  }

  int _getBucketKey(List<double> vec) {
    int key = 0;
    for (int i = 0; i < kHyperplanes; i++) {
      double dot = 0.0;
      final h = _hyperplanes[i];
      for (int j = 0; j < dim; j++) {
        dot += vec[j] * h[j];
      }
      if (dot >= 0) key |= (1 << i);
    }
    return key;
  }

  void addItem(int id, List<double> vec) {
    _itemVectors[id] = vec;
    final key = _getBucketKey(vec);
    _buckets.putIfAbsent(key, () => []).add(id);
  }

  List<int> query(List<double> queryVec, int topN, {int maxCandidates = 256}) {
    if (_itemVectors.isEmpty) return const [];
    if (_itemVectors.length < 256) return _exactScan(queryVec, topN);

    final queryKey = _getBucketKey(queryVec);
    final Set<int> candidateIds = {};

    // 1. Gather exact bucket candidates
    if (_buckets.containsKey(queryKey)) {
      candidateIds.addAll(_buckets[queryKey]!);
    }

    // 2. Multi-probe LSH: probe adjacent Hamming-distance buckets (1-bit flips)
    int bit = 0;
    while (candidateIds.length < maxCandidates && bit < kHyperplanes) {
      final neighborKey = queryKey ^ (1 << bit);
      if (_buckets.containsKey(neighborKey)) {
        candidateIds.addAll(_buckets[neighborKey]!);
      }
      bit++;
    }

    if (candidateIds.isEmpty) {
      candidateIds.addAll(_itemVectors.keys);
    }

    return _rankCandidates(queryVec, candidateIds.toList(), topN);
  }

  List<int> _exactScan(List<double> queryVec, int topN) {
    return _rankCandidates(queryVec, _itemVectors.keys.toList(), topN);
  }

  List<int> _rankCandidates(
    List<double> queryVec,
    List<int> candidates,
    int topN,
  ) {
    final List<MapEntry<int, double>> scored = [];
    for (final id in candidates) {
      final targetVec = _itemVectors[id];
      if (targetVec != null) {
        scored.add(MapEntry(id, _cosineSimilarity(queryVec, targetVec)));
      }
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(topN).map((e) => e.key).toList();
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }
}

// =============================================================
// 3. Contextual Bandit Ranker
//    - Negative signal overrides (skip < 30s => penalty multiplier)
//    - Session penalty decay
//    - Epsilon-greedy exploration (default epsilon = 0.2)
//    - 80/20 exploit/explore queue interleave
// =============================================================

class ContextualBanditRanker {
  final Map<int, double> _negativeOverrides = {}; // songId -> penalty
  final math.Random _random;

  ContextualBanditRanker({int? seed}) : _random = math.Random(seed);

  void registerSkipSignal(int songId) {
    _negativeOverrides[songId] = 0.5; // immediate 50% score penalty
  }

  bool isPenalized(int songId) => _negativeOverrides.containsKey(songId);

  double penaltyFor(int songId) => _negativeOverrides[songId] ?? 1.0;

  void decaySessionPenalties() {
    _negativeOverrides.updateAll((key, val) => val + (1.0 - val) * 0.1);
    _negativeOverrides.removeWhere((key, val) => val >= 0.95);
  }

  /// Sorts candidates by base score (with penalties applied), then with
  /// probability [epsilon] inserts one unplayed discovery track at top-3.
  List<int> rankAndExploit({
    required List<int> candidateIds,
    required Map<int, double> baseScores,
    required Set<int> unplayedCatalogIds,
    double epsilon = 0.2,
  }) {
    final List<MapEntry<int, double>> rankedCandidates = [];
    for (final id in candidateIds) {
      double score = baseScores[id] ?? 0.0;
      if (_negativeOverrides.containsKey(id)) {
        score *= _negativeOverrides[id]!;
      }
      rankedCandidates.add(MapEntry(id, score));
    }
    rankedCandidates.sort((a, b) => b.value.compareTo(a.value));
    final finalQueue = rankedCandidates.map((e) => e.key).toList();

    if (_random.nextDouble() < epsilon) {
      final pool = unplayedCatalogIds.where((id) => !finalQueue.contains(id)).toList();
      if (pool.isNotEmpty) {
        final discoverySong = pool[_random.nextInt(pool.length)];
        final insertPos = finalQueue.length < 2 ? finalQueue.length : 2;
        finalQueue.insert(insertPos, discoverySong);
      }
    }
    return finalQueue;
  }

  /// Interleaves an exploitation-ranked list with an exploration-ranked
  /// list in a 4:1 pattern (80% exploitation / 20% exploration).
  List<int> interleave({
    required List<int> exploitOrder,
    required List<int> exploreOrder,
  }) {
    final result = <int>[];
    final used = <int>{};
    int eIdx = 0, xIdx = 0;
    final total = exploitOrder.length + exploreOrder.length;
    while (result.length < total) {
      for (var i = 0; i < 4 && result.length < total; i++) {
        while (eIdx < exploitOrder.length && !used.add(exploitOrder[eIdx])) {
          eIdx++;
        }
        if (eIdx < exploitOrder.length) {
          result.add(exploitOrder[eIdx]);
          used.add(exploitOrder[eIdx]);
          eIdx++;
        }
      }
      while (xIdx < exploreOrder.length && !used.add(exploreOrder[xIdx])) {
        xIdx++;
      }
      if (xIdx < exploreOrder.length) {
        result.add(exploreOrder[xIdx]);
        used.add(exploreOrder[xIdx]);
        xIdx++;
      }
    }
    return result;
  }
}