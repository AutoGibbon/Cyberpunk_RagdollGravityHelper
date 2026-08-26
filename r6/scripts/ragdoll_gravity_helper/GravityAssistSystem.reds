module Gibbon.RGH.GravityAssist

import Gibbon.RGH.Settings.*

// Height above the puppet's feet the impulse is applied at, approximating center of mass.
public static func RGH_ImpulseHeightM() -> Float {
    return 0.9;
}

// Radius the impulse affects - wide enough to move the whole ragdoll as one, not just a limb.
public static func RGH_ImpulseRadiusM() -> Float {
    return 1.5;
}

// Latch preventing a re-entrant OnRagdollEnabledEvent (the base game can fire it more than
// once per death) from stacking a second parallel tick loop on the same puppet.
@addField(NPCPuppet) public let rgh_assistActive: Bool;

@wrapMethod(NPCPuppet)
protected cb func OnRagdollEnabledEvent(evt: ref<RagdollNotifyEnabledEvent>) -> Bool {
    let result: Bool = wrappedMethod(evt);
    let settings: ref<RGHSettings> = RGHSettings.GetInstance(this.GetGame());

    if !IsDefined(settings) || !settings.enabled || this.rgh_assistActive {
        return result;
    }

    this.rgh_assistActive = true;
    GameInstance.GetDelaySystem(this.GetGame()).DelayCallbackNextFrame(RGHTickCallback.Create(this));
    return result;
}

public class RGHTickCallback extends DelayCallback {
    private let m_target: wref<NPCPuppet>;
    private let m_lastTickTime: Float;
    private let m_startTime: Float;

    public static func Create(target: ref<NPCPuppet>) -> ref<RGHTickCallback> {
        let self: ref<RGHTickCallback> = new RGHTickCallback();
        let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(target.GetGame()));
        self.m_target = target;
        self.m_lastTickTime = now;
        self.m_startTime = now;
        return self;
    }

    public func Call() -> Void {
        let target: wref<NPCPuppet> = this.m_target;
        if !IsDefined(target) {
            return;
        };

        let settings: ref<RGHSettings> = RGHSettings.GetInstance(target.GetGame());
        let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(target.GetGame()));

        if !IsDefined(settings)
            || !settings.enabled
            || !target.IsRagdolling()
            || !ScriptedPuppet.CanRagdoll(target)
            || (now - this.m_startTime) > settings.maxDurationSec {
            target.rgh_assistActive = false;
            return;
        };

        let dt: Float = now - this.m_lastTickTime;
        this.m_lastTickTime = now;

        let pos: Vector4 = target.GetWorldPosition();
        pos.Z += RGH_ImpulseHeightM();

        let impulse: Vector4 = Vector4(0.0, 0.0, -(settings.forceStrength * dt), 1.0);
        target.QueueEvent(CreateRagdollApplyImpulseEvent(pos, impulse, RGH_ImpulseRadiusM()));

        GameInstance.GetDelaySystem(target.GetGame()).DelayCallbackNextFrame(this);
    }
}
