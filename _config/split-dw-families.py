#!/usr/bin/env python3
"""
Разбивает пространство имён dw.* (собственный слой Dreamworld) на смысловые семьи.

[NOT-TESTED]

ЗАЧЕМ СКРИПТОМ, А НЕ ГЛАЗАМИ. Конспект пишется по семьям, и семьи раздаются
разным исполнителям. Если разбиение делать глазами, часть имён потеряется молча -
и потерю будет не видно, потому что каждый раздел по отдельности выглядит целым.
Скрипт даёт СЧЁТНУЮ проверку: сумма по семьям обязана равняться числу dw.*, а
пересечений быть не должно. Имя, не подошедшее ни к одному правилу, едет в семью
"прочее" - оно видно, а не потеряно.

Порядок правил ЗНАЧИМ: первое совпавшее выигрывает. Поэтому узкие правила стоят
раньше широких (dw.ThrallPlacementValidation -> рабы, а не строительство).

Запуск:
    python _config/split-dw-families.py        - отчёт + запись dw-families.json
"""
import json
import re
from pathlib import Path

CFG = Path(__file__).resolve().parent
SRC = CFG / "cvars-registered.txt"
OUT = CFG / "dw-families.json"

# (ключ, человеческое имя, список регулярок). Первое совпадение выигрывает.
FAMILIES = [
    ("ai-lod", "AI LOD и тик-рейты — глубина симуляции мира", [
        r"^dw\.AILOD", r"^dw\.AllowAILODOverlay", r"^dw\.EnableAILODSystem",
        r"^dw\.NpcLOD", r"^dw\.SkeletalMeshTickRate", r"^dw\.cc\.SkeletalMeshTickBatching",
        r"^dw\.ControllerTickRateAudit", r"^dw\.ReapplyControllerTickRates",
        r"^dw\.PlaceableInventoryAILod",
    ]),
    ("spawn-ai", "Спавн NPC, территории, агрессия и оповещение", [
        r"^dw\.EnableAISpawning", r"^dw\.EnableInitialAISpawningPass",
        r"^dw\.(Enable|Max|Exit)\w*NPCTerritorySpawner", r"^dw\.EnableManualSpawnersAiLod",
        r"^dw\.EnableStaticRoamingPaths", r"^dw\.NPCsTarget", r"^dw\.MaxNPCsToNotify",
        r"^dw\.CustomAvoidanceConsiderationRadiusMultiplier", r"^dw\.HearingUpdateInterval",
        r"^dw\.CVarUseHasPartialPathToBuildGiveUpHate", r"^dw\.TrackSelectedNPCRotations",
    ]),
    ("thrall", "Рабы, спутники и общие хранилища", [
        r"^dw\.Thrall", r"^dw\.TeleportThrallHome", r"^dw\.PreloadThrallItems",
        r"^dw\.EnableThrallPlacementValidation",
        r"^dw\.EnableAssignedThrallStorageShare", r"^dw\.EnableFollowerStoragesShare",
        r"^dw\.UseThrallRelevantDistance", r"^dw\.EnableNearbyStoragesShare",
        r"^dw\.EnablePlayerStoragesShare", r"^dw\.VisualizeNearbyStoragesShareRadius",
        r"^dw\.Enable(Build|Craft)FromStorage", r"^dw\.MaxPatronsInPatronInventory",
        r"^dw\.PaidPatronReplenishTime", r"^dw\.PatronMinStayTimeAfterLoad",
    ]),
    ("building", "Строительство, стабильность и размещение", [
        r"^dw\.Build(?!ingReplication|ingData)", r"^dw\.Building(?!Replication|Data)",
        r"^dw\.\w*[Ss]tability", r"^dw\.Placeable", r"^dw\.EnablePlaceable",
        r"^dw\.ExtraDestructRange", r"^dw\.ExtraPlacementRange", r"^dw\.MountingPoint",
        # Дальность дотягивания игрока: тот же класс, что ExtraDestructRange -
        # "на сколько сантиметров руки длиннее".
        r"^dw\.BaseLenientInteractionDistance", r"^dw\.Max\w*InteractionDistance",
        r"^dw\.LogPlaceable", r"^dw\.LogBuildable", r"^dw\.AlwaysPerformPlaceableStability",
        r"^dw\.DestroyPlaceableStabilityLoop", r"^dw\.RecalculateStabilityFor",
        r"^dw\.ForceUseGCDestructionForBuildings", r"^dw\.ShowExtraFailedPlacementInfo",
        r"^dw\.DebugUpgradeSocketCheck", r"^dw\.DebugPlaceableSmartObjectOverlaps",
        r"^dw\.PoiProtectionMinCheckRateOverride",
    ]),
    ("net", "Репликация, сеть и listen-сервер", [
        r"^dw\.BuildingReplication", r"^dw\.BuildingData_Compression",
        r"^dw\.\w*StabilityData_Compression", r"^dw\.UsePerConnectionObjectList",
        r"^dw\.NetClientFloatsDuringNavWalking", r"^dw\.ForceLinearPrediction",
        r"^dw\.DebugHudReplicationInterval", r"^dw\.AllowInGameJoin",
        r"^dw\.ServerPopulation", r"^dw\.IsClientMatchingKnockbackAnimEnabled",
        r"^dw\.TeleportServerAuthMoveDuration", r"^dw\.TeleportTimeout",
        r"^dw\.RepossessCharacterOnLogin", r"^dw\.MaxAdditionalServerHealthInteractionDistance",
    ]),
    ("nav-move", "Навигация, лазание и движение персонажа", [
        r"^dw\.nav\.", r"^dw\.DefaultPathFollowing", r"^dw\.PlayerNavInvoker",
        r"^dw\.DrawStaticNavigationRadius", r"^dw\.DrawDebugRecoverOffMesh",
        r"^dw\.Climb", r"^dw\.DebugClimbing", r"^dw\.MaxStepHeightOverride",
        r"^dw\.FloorSweepFailRadiusAdjust", r"^dw\.UseCachedValidFloorData",
        r"^dw\.PerformUnsafeMovementChecks", r"^dw\.CanMoveToTimeStep",
        r"^dw\.IgnoreGravityForUnjoinedPlayers", r"^dw\.aba\.",
        r"^dw\.TimeToWalkToMount", r"^dw\.EnsurePlayerLocationValidOnSpawn",
        r"^dw\.ForceUseDBSpawnLocation", r"^dw\.SelectiveLoadLocation",
    ]),
    ("gfx", "Графика, погода и производительность", [
        r"^dw\.GrassOcclusion", r"^dw\.LowPerformance", r"^dw\.DisableWeatherSystem",
        r"^dw\.EnableWeatherDebugPrint", r"^dw\.SkyHelperVolumeBoundsCheckingEnabled",
        r"^dw\.WaterInteraction", r"^dw\.EnablePhysicsBodyCreationDebugSpheres",
        r"^dw\.GUIForceGarbageThreshold", r"^dw\.StartingEmoteInSectionEnabled",
    ]),
    ("stream", "Стриминг мира, память и загрузка", [
        r"^dw\.SelectiveLoad", r"^dw\.WCStreamAroundAllClientsInListenServer",
        r"^dw\.MaxLevelLoadFailureCount", r"^dw\.MinSuccessfulLevelPostLoadSeconds",
        r"^dw\.MemoryPressure", r"^dw\.SaveGameLoader", r"^dw\.EnableRegionTravel",
        r"^dw\.EnableDevDungeonTravel", r"^dw\.MaxItemCountToRefreshPerTick",
        r"^dw\.ExternalDirectory",
    ]),
    ("debug-db", "Отладка, OSD, телеметрия и база данных", [
        r"^dw\.OSD\.", r"^dw\.EnableDeveloperMode", r"^dw\.Debug", r"^dw\.DrawDebug",
        r"^dw\.GameEvent", r"^dw\.GameplayTelemetry", r"^dw\.GameDbWorkingSpaceKb",
        r"^dw\.ForceGameDBOpenFail", r"^dw\.\w*MetricsFlushTime", r"^dw\.Hearbeat",
        r"^dw\.Heartbeat", r"^dw\.ItemTransactionMetricsFlushTime",
        r"^dw\.(Start|Stop)RepeatCommand", r"^dw\.UseConsoleKeybindingsVersion",
        r"^dw\.UseModControllerCache", r"^dw\.RedundantPlatformSpecifier",
        r"^dw\.LogSpellActorLoadTime", r"^dw\.LongPressTriggerTime",
    ]),
]


def main():
    names = [l.strip() for l in SRC.read_text(encoding="utf-8").splitlines()
             if l.startswith("dw.")]
    compiled = [(k, t, [re.compile(p) for p in pats]) for k, t, pats in FAMILIES]

    buckets = {k: [] for k, _, _ in compiled}
    buckets["other"] = []
    titles = {k: t for k, t, _ in compiled}
    titles["other"] = "Прочее — правило не подошло, разобрать глазами"

    for n in names:
        for key, _, pats in compiled:
            if any(p.search(n) for p in pats):
                buckets[key].append(n)
                break
        else:
            buckets["other"].append(n)

    total = sum(len(v) for v in buckets.values())
    print(f"{'семья':14} {'шт':>4}  название")
    print("-" * 78)
    for k in list(titles):
        print(f"{k:14} {len(buckets[k]):>4}  {titles[k]}")
    print("-" * 78)
    ok = total == len(names)
    print(f"КОНТРОЛЬ ПОЛНОТЫ: имён dw.* {len(names)}, разложено {total} -> "
          + ("СОШЛОСЬ" if ok else "ПОТЕРЯ"))

    if buckets["other"]:
        print("\nне подошли ни к одному правилу:")
        for n in buckets["other"]:
            print(f"   {n}")

    OUT.write_text(json.dumps(
        {"titles": titles, "families": buckets}, ensure_ascii=False, indent=2),
        encoding="utf-8")
    print(f"\nзаписано: {OUT.name}")


if __name__ == "__main__":
    main()
