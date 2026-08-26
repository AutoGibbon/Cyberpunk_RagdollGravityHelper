module Gibbon.RGH.Settings

public class RGHSettings extends ScriptableSystem {
    public static func GetInstance(gameInstance: GameInstance) -> ref<RGHSettings> {
        return GameInstance.GetScriptableSystemsContainer(gameInstance).Get(n"Gibbon.RGH.Settings.RGHSettings") as RGHSettings;
    }

    public func OnAttach() -> Void {
        ModSettings.RegisterListenerToClass(this);
    }

    public func OnDetach() -> Void {
        ModSettings.UnregisterListenerToClass(this);
    }

    public cb func OnModSettingsChange() -> Void {
        // Values are read directly by GravityAssistSystem each tick - nothing to reconcile.
    }

    @runtimeProperty("ModSettings.mod", "Ragdoll Physics Helper")
    @runtimeProperty("ModSettings.displayName", "Enabled")
    public let enabled: Bool = true;

    @runtimeProperty("ModSettings.mod", "Ragdoll Physics Helper")
    @runtimeProperty("ModSettings.displayName", "Force Strength")
    @runtimeProperty("ModSettings.description", "Downward force applied to ragdolling NPCs, per second of fall time.")
    @runtimeProperty("ModSettings.step", "0.5")
    @runtimeProperty("ModSettings.min", "0.0")
    @runtimeProperty("ModSettings.max", "50.0")
    @runtimeProperty("ModSettings.dependency", "enabled")
    public let forceStrength: Float = 28.0;

    @runtimeProperty("ModSettings.mod", "Ragdoll Physics Helper")
    @runtimeProperty("ModSettings.displayName", "Max Assist Duration")
    @runtimeProperty("ModSettings.description", "Safety cap (seconds): stop pushing a ragdoll after this long.")
    @runtimeProperty("ModSettings.step", "0.5")
    @runtimeProperty("ModSettings.min", "1.0")
    @runtimeProperty("ModSettings.max", "5.0")
    @runtimeProperty("ModSettings.dependency", "enabled")
    public let maxDurationSec: Float = 1.5;
}
