import 'package:piecemeal/piecemeal.dart';

import '../core/actor.dart';
import '../core/combat.dart';
import '../core/game.dart';
import '../items/inventory.dart';
import '../items/item.dart';
import 'action.dart';
import 'item.dart';
import 'los.dart';

/// [Action] for throwing an [Item].
///
/// This is referred to as "toss" in the code but as "throw" in the user
/// interface. "Toss" is used just to avoid using "throw" in code, which is a
/// reserved word.
class TossAction extends ItemAction {
  final Hit _hit;
  final Vec _target;

  TossAction(ItemLocation location, Item item, this._hit, this._target)
      : super(location, item);

  @override
  ActionResult onPerform() {
    if (!item.canToss) return fail("{1} can't be thrown.", item);

    Item tossed;
    if (item.count == 1) {
      // Throwing the entire stack.
      tossed = item;
      removeItem();
    } else {
      // Throwing one item from a stack.
      tossed = item.splitStack(1);
      countChanged();
    }

    // Take the item and throw it.
    return alternate(TossLosAction(_target, tossed, _hit));
  }
}

/// Action for handling the path of a thrown item while it's in flight.
class TossLosAction extends LosAction {
  final Item _item;
  final Hit _hit;

  /// `true` if the item has reached an [Actor] and failed to hit it. When this
  /// happens, the item will keep flying past its target until the end of its
  /// range.
  bool _missed = false;

  @override
  int get range => _hit.range;

  TossLosAction(Vec target, this._item, this._hit) : super(target);

  @override
  void onStep(Vec previous, Vec pos) {
    addEvent(EventType.toss, pos: pos, other: _item);
  }

  @override
  bool onHitActor(Vec pos, Actor target) {
    // TODO: Range should affect strike.
    if (_hit.perform(this, actor, target) == 0) {
      // The item missed, so keep flying.
      _missed = true;
      return false;
    }

    _endThrow(pos);
    return true;
  }

  @override
  void onEnd(Vec pos) {
    _endThrow(pos);
  }

  @override
  bool onTarget(Vec pos) {
    // If the item failed to make contact with an actor, it's no longer well
    // targeted and just keeps going.
    if (_missed) return false;

    _endThrow(pos);

    // Let the player aim at a specific tile on the ground.
    return true;
  }

  void _endThrow(Vec pos) {
    var toss = _item.toss!;

    // TODO: I think there's a bug here somewhere. Sometimes, when you throw a
    // bottled element at a monster, it seems to only do the toss damage of the
    // bottle itself, and not the effect damage too.
    // See if the item does something when it hits.
    if (toss.use != null) {
      addAction(toss.use!(pos));
      return;
    }

    // See if it breaks.
    if (rng.percent(toss.breakage)) {
      log("{1} breaks!", _item);
      return;
    }

    // Drop the item onto the ground.
    game.stage.addItem(_item, pos);
  }
}
