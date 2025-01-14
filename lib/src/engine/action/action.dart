import 'package:piecemeal/piecemeal.dart';

import '../core/actor.dart';
import '../core/element.dart';
import '../core/game.dart';
import '../core/log.dart';
import '../hero/hero.dart';
import '../monster/monster.dart';
import '../stage/sound.dart';

abstract class Action {
  Actor? _actor;

  // TODO: Now that Action has this, should Action subclasses that need a
  // position use it?
  late final Vec _pos;
  late final Game _game;

  late final bool _consumesEnergy;

  Game get game => _game;

  // TODO: Instead of making this nullable, split out actions with actors into
  // a separate subclass where the field is always non-null. Most actions will
  // always have an actor. It's only a few like burning floors that don't.
  Actor? get actor => _actor;

  Monster get monster => _actor as Monster;

  Hero get hero => _actor as Hero;

  bool get consumesEnergy => _consumesEnergy;

  /// Whether this action can be immediately performed in the middle of an
  /// ongoing action or should wait until the current action is finished.
  bool get isImmediate => true;

  void bind(Actor actor, {bool? consumesEnergy}) {
    _actor = actor;
    _pos = actor.pos;
    _game = actor.game;
    _consumesEnergy = consumesEnergy ?? true;
  }

  /// Binds an action created passively by the dungeon.
  void bindPassive(Game game, Vec pos) {
    _pos = pos;
    _game = game;
    _consumesEnergy = false;
  }

  /// Binds an action created passively by the dungeon.
  void _bind(Actor actor, Vec pos, Game game) {
    _actor = actor;
    _pos = pos;
    _game = game;
    _consumesEnergy = false;
  }

  ActionResult perform() {
    return onPerform();
  }

  ActionResult onPerform();

  /// Enqueue a secondary action that is a consequence of this one.
  ///
  /// If [action] is immediate (`isImmediate` returns true), then the action
  /// will be performed in the current tick before the current action continues
  /// to process. Otherwise, it will be enqueued and run once the current action
  /// and any other enqueued actions are done.
  void addAction(Action action, [Actor? actor]) {
    action._bind(actor ?? _actor!, _pos, _game);
    _game.addAction(action);
  }

  void addEvent(EventType type,
      {Actor? actor,
      Element? element,
      Object? other,
      Vec? pos,
      Direction? dir}) {
    _game.addEvent(type,
        actor: actor, element: element, pos: pos, dir: dir, other: other);
  }

  /// How much noise is produced by this action. Override to make certain
  /// actions quieter or louder.
  double get noise => Sound.normalNoise;

  void error(String message, [Noun? noun1, Noun? noun2, Noun? noun3]) {
    if (!game.stage[_pos].isVisible) return;
    _game.log.error(message, noun1, noun2, noun3);
  }

  void log(String message, [Noun? noun1, Noun? noun2, Noun? noun3]) {
    if (!game.stage[_pos].isVisible) return;
    _game.log.message(message, noun1, noun2, noun3);
  }

  void gain(String message, [Noun? noun1, Noun? noun2, Noun? noun3]) {
    if (!game.stage[_pos].isVisible) return;
    _game.log.gain(message, noun1, noun2, noun3);
  }

  ActionResult succeed(
      [String? message, Noun? noun1, Noun? noun2, Noun? noun3]) {
    if (message != null) log(message, noun1, noun2, noun3);
    return ActionResult.success;
  }

  ActionResult fail([String? message, Noun? noun1, Noun? noun2, Noun? noun3]) {
    if (message != null) error(message, noun1, noun2, noun3);
    return ActionResult.failure;
  }

  ActionResult alternate(Action action) {
    action.bind(_actor!, consumesEnergy: _consumesEnergy);
    return ActionResult.alternate(action);
  }

  /// Returns [ActionResult.success] if [done] is `true`, otherwise returns
  /// [ActionResult.notDone].
  ActionResult doneIf(bool done) {
    return done ? ActionResult.success : ActionResult.notDone;
  }
}

class ActionResult {
  static const success = ActionResult(succeeded: true, done: true);
  static const failure = ActionResult(succeeded: false, done: true);
  static const notDone = ActionResult(succeeded: true, done: false);

  /// An alternate [Action] that should be performed instead of the one that
  /// failed to perform and returned this. For example, when the [Hero] walks
  /// into a closed door, a WalkAction will fail (the door is closed) and
  /// return an alternate OpenDoorAction instead.
  final Action? alternative;

  /// `true` if the [Action] was successful and energy should be consumed.
  final bool succeeded;

  /// `true` if the [Action] does not need any further processing.
  final bool done;

  const ActionResult({required this.succeeded, required this.done})
      : alternative = null;

  const ActionResult.alternate(this.alternative)
      : succeeded = false,
        done = true;
}

/// Attempts to perform an action that spends focus.
class FocusAction extends Action {
  /// The focus cost of the action.
  final int _focus;

  /// The action to perform if the hero has enough focus.
  final Action _action;

  FocusAction(this._focus, this._action);

  @override
  ActionResult onPerform() {
    if (hero.focus < _focus) return fail("You aren't focused enough.");

    hero.spendFocus(_focus);
    return alternate(_action);
  }
}

/// Attempts to perform an action that spends fury.
class FuryAction extends Action {
  /// The fury cost of the action.
  final int _fury;

  /// The action to perform if the hero has enough focus.
  final Action _action;

  FuryAction(this._fury, this._action);

  @override
  ActionResult onPerform() {
    if (hero.fury < _fury) return fail("You aren't angry enough.");

    hero.spendFury(_fury);
    return alternate(_action);
  }
}

// TODO: Use this for more actions.
/// For multi-step actions, lets you define one using a `sync*` function and
/// `yield` instead of building the state machine manually.
mixin GeneratorActionMixin on Action {
  /// Start the generator the first time through.
  late final Iterator<ActionResult> _iterator = onGenerate().iterator;

  @override
  ActionResult onPerform() {
    // If it reaches the end, it succeeds.
    if (!_iterator.moveNext()) return ActionResult.success;

    return _iterator.current;
  }

  /// Wait a single frame.
  ActionResult waitOne() => ActionResult.notDone;

  /// Wait [frames] frames.
  Iterable<ActionResult> wait(int frames) =>
      List.generate(frames, (_) => ActionResult.notDone);

  Iterable<ActionResult> onGenerate();
}
