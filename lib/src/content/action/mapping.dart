import 'package:piecemeal/piecemeal.dart';

import '../../engine.dart';

/// An [Action] that flows out and maps tiles within a certain distance.
class MappingAction extends Action {
  final int _maxDistance;
  final bool _illuminate;
  int _currentDistance = 0;

  /// The different distances (squared) that contain tiles, in reverse order
  /// for easy removal of the nearest distance.
  late final List<List<Vec>> _tilesByDistance = _findTiles();

  @override
  bool get isImmediate => false;

  MappingAction(this._maxDistance, {bool? illuminate})
      : _illuminate = illuminate ?? false;

  @override
  ActionResult onPerform() {
    for (var i = 0; i < 2; i++) {
      // If we've shown all the tiles, we're done.
      if (_currentDistance >= _tilesByDistance.length) {
        return ActionResult.success;
      }

      for (var pos in _tilesByDistance[_currentDistance]) {
        game.stage.explore(pos, force: true);
        addEvent(EventType.map, pos: pos);

        if (_illuminate) {
          game.stage[pos].addEmanation(255);
          game.stage.floorEmanationChanged();
        }

        // Update the neighbors too mainly so that walls get explored.
        for (var neighbor in pos.neighbors) {
          game.stage.explore(neighbor, force: true);
        }
      }

      _currentDistance++;
    }

    return ActionResult.notDone;
  }

  /// Finds all the tiles that should be detected and organizes them from
  /// farthest to nearest.
  List<List<Vec>> _findTiles() {
    var result = <List<Vec>>[[]];
    result[0].add(actor!.pos);

    var flow = MappingFlow(game.stage, actor!.pos, _maxDistance);

    for (var pos in flow.reachable) {
      var distance = flow.costAt(pos)!;
      for (var i = result.length; i <= distance; i++) {
        result.add([]);
      }

      result[distance].add(pos);
    }

    for (var i = 0; i < result.length; i++) {
      rng.shuffle(result[i]);
    }

    return result;
  }
}

/// Flows through any visible or traversable tiles, treating diagonals as a
/// little longer to give a nice round edge to the perimeter.
class MappingFlow extends Flow {
  final int _maxDistance;

  MappingFlow(Stage stage, Vec start, this._maxDistance)
      : super(stage, start, maxDistance: _maxDistance);

  /// The cost to enter [tile] at [pos] or `null` if the tile cannot be entered.
  @override
  int? tileCost(int parentCost, Vec pos, Tile tile, bool isDiagonal) {
    // Can't enter impassable tiles.
    if (!tile.canEnter(Motility.doorAndFly)) return null;

    // TODO: Assumes cost == distance.
    // Can't reach if it's too far.
    if (parentCost >= _maxDistance * 2) return null;

    return isDiagonal ? 3 : 2;
  }
}
