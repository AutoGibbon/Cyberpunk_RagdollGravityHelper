module Gibbon.RGH.GravityAssist

import Gibbon.RGH.Settings.*
import Gibbon.RGH.Logging.*

@wrapMethod(HitReactionComponent) 
private func GetPhysicalImpulse(attackData: ref<AttackData>, hitPosition: Vector4, out frameImpulse: Float) -> Float {
    let originalImpulse: Float = wrappedMethod(attackData, hitPosition, frameImpulse);
    
    // If the attack is a bullet/projectile, suppress its impulse.
    if AttackData.IsRangedOrDirect(attackData.GetAttackType()) {
        frameImpulse = frameImpulse * 0.5;       
        this.m_ragdollImpulse = this.m_ragdollImpulse * 0.5;  
        return originalImpulse * 0.5;               
    };
    
    // For non-ranged attacks (melee, etc.), use the original impulse to preserve their behavior.
    return originalImpulse;
}


// Height above the puppet's feet the impulse is applied at, approximating center of mass.
public static func RGH_ImpulseHeightM() -> Float {
    return 0.9;
}

// Radius the impulse affects - wide enough to move the whole ragdoll as one, not just a limb.
public static func RGH_ImpulseRadiusM() -> Float {
    return 1.0;
}

// Duration over which the impulse anchor moves from RGH_ImpulseHeightM() down to the puppet's
// base position - keeps the push centered on the body early in a fall, converging to the pivot
// once it's likely landed so it doesn't keep nudging a body that's already settled.
public static func RGH_ImpulseHeightTransitionS() -> Float {
    return 1.0;
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
    RGHLog(s"assist started for \(ToString(this.GetEntityID()))");
    GameInstance.GetDelaySystem(this.GetGame()).DelayCallback(RGHTickCallback.Create(this), 0.05);
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

    // Continues an existing tick loop on a fresh instance, carrying timing state forward.
    // DelayCallbackNextFrame(this) from inside its own Call() never re-fires (confirmed via
    // logging); DelayCallback(newInstance, delay) is the pattern actually used by other mods
    // (e.g. ChromePlating's CPUpdateCallback) for a recurring tick.
    private static func Continue(prev: ref<RGHTickCallback>) -> ref<RGHTickCallback> {
        let self: ref<RGHTickCallback> = new RGHTickCallback();
        self.m_target = prev.m_target;
        self.m_lastTickTime = prev.m_lastTickTime;
        self.m_startTime = prev.m_startTime;
        return self;
    }

    public func Call() -> Void {
        let target: wref<NPCPuppet> = this.m_target;
        if !IsDefined(target) {
            RGHLog("assist stopped: target no longer defined");
            return;
        };

        let settings: ref<RGHSettings> = RGHSettings.GetInstance(target.GetGame());
        let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(target.GetGame()));

        if !IsDefined(settings) || !settings.enabled {
            RGHLog(s"assist stopped for \(ToString(target.GetEntityID())): settings disabled or missing");
            target.rgh_assistActive = false;
            return;
        };
        if !target.IsRagdolling() {
            RGHLog(s"assist stopped for \(ToString(target.GetEntityID())): no longer ragdolling");
            target.rgh_assistActive = false;
            return;
        };
        if !ScriptedPuppet.CanRagdoll(target) {
            RGHLog(s"assist stopped for \(ToString(target.GetEntityID())): puppet can no longer ragdoll");
            target.rgh_assistActive = false;
            return;
        };
        if (now - this.m_startTime) > settings.maxDurationSec {
            RGHLog(s"assist stopped for \(ToString(target.GetEntityID())): safety-cap duration reached");
            target.rgh_assistActive = false;
            return;
        };

        let dt: Float = now - this.m_lastTickTime;
        this.m_lastTickTime = now;

        let heightT: Float = ClampF((now - this.m_startTime) / RGH_ImpulseHeightTransitionS(), 0.0, 1.0);
        let height: Float = RGH_ImpulseHeightM() * (1.0 - heightT);

        let pos: Vector4 = target.GetWorldPosition();
        pos.Z += height;

        let impulse: Vector4 = Vector4(0.0, 0.0, -(settings.forceStrength * dt), 1.0);
        target.QueueEvent(CreateRagdollApplyImpulseEvent(pos, impulse, RGH_ImpulseRadiusM()));

        GameInstance.GetDelaySystem(target.GetGame()).DelayCallback(RGHTickCallback.Continue(this), 0.05);
    }
}
