#!/usr/bin/env python3
"""Generate MacExplorer.xcodeproj/project.pbxproj."""

from __future__ import annotations

import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = "MacExplorer"
BUNDLE_ID = "com.thehordeforge.MacExplorer"
DEPLOYMENT = "26.0"


def nid() -> str:
    return uuid.uuid4().hex[:24].upper()


def main() -> None:
    app_dir = ROOT / "MacExplorer"
    tests_dir = ROOT / "MacExplorerTests"

    app_swifts = sorted(app_dir.rglob("*.swift"))
    test_swifts = sorted(tests_dir.rglob("*.swift"))
    assets = app_dir / "Assets.xcassets"
    strings = app_dir / "Resources" / "Localizable.xcstrings"
    entitlements = app_dir / "MacExplorer.entitlements"
    info_plist = app_dir / "Info.plist"

    file_refs: dict[Path, str] = {}
    build_files: dict[Path, str] = {}
    for path in app_swifts + test_swifts + [assets, strings, entitlements, info_plist]:
        file_refs[path] = nid()
        if path not in (entitlements, info_plist):
            build_files[path] = nid()

    group_ids: dict[Path, str] = {app_dir: nid(), tests_dir: nid()}
    for path in list(file_refs):
        parent = path.parent
        while parent not in (ROOT, app_dir.parent) and parent != tests_dir.parent:
            if parent not in group_ids and (app_dir in parent.parents or parent == app_dir or tests_dir in parent.parents or parent == tests_dir):
                group_ids[parent] = nid()
            if parent in (app_dir, tests_dir):
                break
            parent = parent.parent

    ids = {
        "project": nid(),
        "main": nid(),
        "products": nid(),
        "app_target": nid(),
        "test_target": nid(),
        "app_product": nid(),
        "test_product": nid(),
        "sources_app": nid(),
        "sources_tests": nid(),
        "resources": nid(),
        "fw_app": nid(),
        "fw_tests": nid(),
        "proj_cfgs": nid(),
        "app_cfgs": nid(),
        "test_cfgs": nid(),
        "dbg_proj": nid(),
        "rel_proj": nid(),
        "dbg_app": nid(),
        "rel_app": nid(),
        "dbg_test": nid(),
        "rel_test": nid(),
        "proxy": nid(),
        "dep": nid(),
    }
    app_group = group_ids[app_dir]
    tests_group = group_ids[tests_dir]

    def kids(dir_path: Path) -> str:
        items: list[str] = []
        for sub in sorted([p for p in group_ids if p.parent == dir_path], key=lambda p: p.name):
            items.append(f"{group_ids[sub]} /* {sub.name} */")
        for path in sorted([p for p in file_refs if p.parent == dir_path], key=lambda p: p.name):
            items.append(f"{file_refs[path]} /* {path.name} */")
        return ", ".join(items)

    o: list[str] = []
    a = o.append
    a("// !$*UTF8*$!")
    a("{")
    a("\tarchiveVersion = 1;")
    a("\tclasses = {};")
    a("\tobjectVersion = 56;")
    a("\tobjects = {")
    a("")

    a("/* Begin PBXBuildFile section */")
    for path, bid in build_files.items():
        phase = "Sources" if path.suffix == ".swift" else "Resources"
        a(f"\t\t{bid} /* {path.name} in {phase} */ = {{isa = PBXBuildFile; fileRef = {file_refs[path]} /* {path.name} */; }};")
    a("/* End PBXBuildFile section */")
    a("")

    a("/* Begin PBXContainerItemProxy section */")
    a(f"\t\t{ids['proxy']} /* PBXContainerItemProxy */ = {{")
    a("\t\t\tisa = PBXContainerItemProxy;")
    a(f"\t\t\tcontainerPortal = {ids['project']} /* Project object */;")
    a("\t\t\tproxyType = 1;")
    a(f"\t\t\tremoteGlobalIDString = {ids['app_target']};")
    a(f"\t\t\tremoteInfo = {PROJECT};")
    a("\t\t};")
    a("/* End PBXContainerItemProxy section */")
    a("")

    a("/* Begin PBXFileReference section */")
    a(f"\t\t{ids['app_product']} /* {PROJECT}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {PROJECT}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    a(f"\t\t{ids['test_product']} /* {PROJECT}Tests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = {PROJECT}Tests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
    for path, ref in file_refs.items():
        if path.suffix == ".swift":
            ftype = "sourcecode.swift"
        elif path.name.endswith(".xcassets"):
            ftype = "folder.assetcatalog"
        elif path.suffix == ".xcstrings":
            ftype = "text.json.xcstrings"
        elif path.suffix == ".entitlements":
            ftype = "text.plist.entitlements"
        else:
            ftype = "text.plist.xml"
        a(f"\t\t{ref} /* {path.name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {path.name}; sourceTree = \"<group>\"; }};")
    a("/* End PBXFileReference section */")
    a("")

    a("/* Begin PBXFrameworksBuildPhase section */")
    a(f"\t\t{ids['fw_app']} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")
    a(f"\t\t{ids['fw_tests']} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")
    a("/* End PBXFrameworksBuildPhase section */")
    a("")

    a("/* Begin PBXGroup section */")
    a(f"\t\t{ids['main']} = {{")
    a("\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = ({app_group} /* MacExplorer */, {tests_group} /* MacExplorerTests */, {ids['products']} /* Products */);")
    a('\t\t\tsourceTree = "<group>";')
    a("\t\t};")
    a(f"\t\t{ids['products']} /* Products */ = {{")
    a("\t\t\tisa = PBXGroup;")
    a(f"\t\t\tchildren = ({ids['app_product']} /* {PROJECT}.app */, {ids['test_product']} /* {PROJECT}Tests.xctest */);")
    a("\t\t\tname = Products;")
    a('\t\t\tsourceTree = "<group>";')
    a("\t\t};")
    for path, gid in sorted(group_ids.items(), key=lambda kv: str(kv[0])):
        a(f"\t\t{gid} /* {path.name} */ = {{")
        a("\t\t\tisa = PBXGroup;")
        a(f"\t\t\tchildren = ({kids(path)});")
        a(f"\t\t\tpath = {path.name};")
        a('\t\t\tsourceTree = "<group>";')
        a("\t\t};")
    a("/* End PBXGroup section */")
    a("")

    a("/* Begin PBXNativeTarget section */")
    a(f"\t\t{ids['app_target']} /* {PROJECT} */ = {{")
    a("\t\t\tisa = PBXNativeTarget;")
    a(f"\t\t\tbuildConfigurationList = {ids['app_cfgs']} /* Build configuration list for PBXNativeTarget \"{PROJECT}\" */;")
    a(f"\t\t\tbuildPhases = ({ids['sources_app']} /* Sources */, {ids['frameworks']} /* Frameworks */, {ids['resources']} /* Resources */);".replace(ids.get('frameworks',''), ids['fw_app']))
    a("\t\t\tbuildRules = ();")
    a("\t\t\tdependencies = ();")
    a(f"\t\t\tname = {PROJECT};")
    a(f"\t\t\tproductName = {PROJECT};")
    a(f"\t\t\tproductReference = {ids['app_product']} /* {PROJECT}.app */;")
    a("\t\t\tproductType = \"com.apple.product-type.application\";")
    a("\t\t};")
    # Fix the botched replace above - rewrite app target cleanly at end
    a("/* End PBXNativeTarget section */")

    text = "\n".join(o)
    # The app target line is broken. Rewrite whole native targets properly.
    print("Script incomplete path — writing final version via alternate method")
    write_final(
        app_swifts,
        test_swifts,
        assets,
        None,
        sorted(app_dir.rglob("*.strings")),
        entitlements,
        info_plist,
        app_dir,
        tests_dir,
    )


def write_final(app_swifts, test_swifts, assets, strings, string_tables, entitlements, info_plist, app_dir, tests_dir) -> None:
    # Fully self-contained final writer
    file_refs: dict[Path, str] = {}
    build_files: dict[Path, str] = {}
    resource_paths = [assets, *string_tables]
    if strings is not None and Path(strings).exists():
        resource_paths.insert(1, Path(strings))
    for path in app_swifts + test_swifts + resource_paths + [entitlements, info_plist]:
        file_refs[path] = nid()
        if path not in (entitlements, info_plist):
            build_files[path] = nid()

    group_ids: dict[Path, str] = {app_dir: nid(), tests_dir: nid()}
    for path in file_refs:
        cur = path.parent
        while cur not in (ROOT,):
            if (app_dir == cur or app_dir in cur.parents) or (tests_dir == cur or tests_dir in cur.parents):
                group_ids.setdefault(cur, nid())
            if cur in (app_dir, tests_dir):
                break
            cur = cur.parent

    I = {k: nid() for k in [
        "project", "main", "products", "app_target", "test_target", "app_product", "test_product",
        "sources_app", "sources_tests", "resources", "fw_app", "fw_tests",
        "proj_cfgs", "app_cfgs", "test_cfgs",
        "dbg_proj", "rel_proj", "dbg_app", "rel_app", "dbg_test", "rel_test",
        "proxy", "dep",
    ]}
    app_group = group_ids[app_dir]
    tests_group = group_ids[tests_dir]

    def kids(dir_path: Path) -> str:
        items: list[str] = []
        for sub in sorted([p for p in group_ids if p.parent == dir_path], key=lambda p: p.name):
            items.append(f"{group_ids[sub]} /* {sub.name} */")
        for path in sorted([p for p in file_refs if p.parent == dir_path], key=lambda p: p.name):
            items.append(f"{file_refs[path]} /* {path.name} */")
        return ", ".join(items)

    app_source_builds = [f"{build_files[p]} /* {p.name} in Sources */" for p in app_swifts]
    test_source_builds = [f"{build_files[p]} /* {p.name} in Sources */" for p in test_swifts]
    resource_builds = [f"{build_files[assets]} /* Assets.xcassets in Resources */"]
    if strings is not None and Path(strings).exists() and Path(strings) in build_files:
        resource_builds.append(f"{build_files[Path(strings)]} /* {Path(strings).name} in Resources */")
    resource_builds += [f"{build_files[p]} /* {p.name} in Resources */" for p in string_tables]

    lines: list[str] = []
    w = lines.append
    w("// !$*UTF8*$!")
    w("{")
    w("\tarchiveVersion = 1;")
    w("\tclasses = {};")
    w("\tobjectVersion = 56;")
    w("\tobjects = {")
    w("")
    w("/* Begin PBXBuildFile section */")
    for path, bid in build_files.items():
        phase = "Sources" if path.suffix == ".swift" else "Resources"
        w(f"\t\t{bid} /* {path.name} in {phase} */ = {{isa = PBXBuildFile; fileRef = {file_refs[path]} /* {path.name} */; }};")
    w("/* End PBXBuildFile section */")
    w("")
    w("/* Begin PBXContainerItemProxy section */")
    w(f"\t\t{I['proxy']} /* PBXContainerItemProxy */ = {{")
    w("\t\t\tisa = PBXContainerItemProxy;")
    w(f"\t\t\tcontainerPortal = {I['project']} /* Project object */;")
    w("\t\t\tproxyType = 1;")
    w(f"\t\t\tremoteGlobalIDString = {I['app_target']};")
    w(f"\t\t\tremoteInfo = {PROJECT};")
    w("\t\t};")
    w("/* End PBXContainerItemProxy section */")
    w("")
    w("/* Begin PBXFileReference section */")
    w(f"\t\t{I['app_product']} /* {PROJECT}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {PROJECT}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    w(f"\t\t{I['test_product']} /* {PROJECT}Tests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = {PROJECT}Tests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
    for path, ref in file_refs.items():
        if path.suffix == ".swift":
            ftype = "sourcecode.swift"
        elif path.name.endswith(".xcassets"):
            ftype = "folder.assetcatalog"
        elif path.suffix == ".xcstrings":
            ftype = "text.json.xcstrings"
        elif path.suffix == ".strings":
            ftype = "text.plist.strings"
        elif path.suffix == ".entitlements":
            ftype = "text.plist.entitlements"
        else:
            ftype = "text.plist.xml"
        w(f"\t\t{ref} /* {path.name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {path.name}; sourceTree = \"<group>\"; }};")
    w("/* End PBXFileReference section */")
    w("")
    w("/* Begin PBXFrameworksBuildPhase section */")
    w(f"\t\t{I['fw_app']} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")
    w(f"\t\t{I['fw_tests']} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")
    w("/* End PBXFrameworksBuildPhase section */")
    w("")
    w("/* Begin PBXGroup section */")
    w(f"\t\t{I['main']} = {{")
    w("\t\t\tisa = PBXGroup;")
    w(f"\t\t\tchildren = ({app_group} /* MacExplorer */, {tests_group} /* MacExplorerTests */, {I['products']} /* Products */);")
    w('\t\t\tsourceTree = "<group>";')
    w("\t\t};")
    w(f"\t\t{I['products']} /* Products */ = {{")
    w("\t\t\tisa = PBXGroup;")
    w(f"\t\t\tchildren = ({I['app_product']} /* {PROJECT}.app */, {I['test_product']} /* {PROJECT}Tests.xctest */);")
    w("\t\t\tname = Products;")
    w('\t\t\tsourceTree = "<group>";')
    w("\t\t};")
    for path, gid in sorted(group_ids.items(), key=lambda kv: str(kv[0])):
        w(f"\t\t{gid} /* {path.name} */ = {{")
        w("\t\t\tisa = PBXGroup;")
        w(f"\t\t\tchildren = ({kids(path)});")
        w(f"\t\t\tpath = {path.name};")
        w('\t\t\tsourceTree = "<group>";')
        w("\t\t};")
    w("/* End PBXGroup section */")
    w("")
    w("/* Begin PBXNativeTarget section */")
    w(f"\t\t{I['app_target']} /* {PROJECT} */ = {{")
    w("\t\t\tisa = PBXNativeTarget;")
    w(f"\t\t\tbuildConfigurationList = {I['app_cfgs']} /* Build configuration list for PBXNativeTarget \"{PROJECT}\" */;")
    w(f"\t\t\tbuildPhases = ({I['sources_app']} /* Sources */, {I['fw_app']} /* Frameworks */, {I['resources']} /* Resources */);")
    w("\t\t\tbuildRules = ();")
    w("\t\t\tdependencies = ();")
    w(f"\t\t\tname = {PROJECT};")
    w(f"\t\t\tproductName = {PROJECT};")
    w(f"\t\t\tproductReference = {I['app_product']} /* {PROJECT}.app */;")
    w('\t\t\tproductType = "com.apple.product-type.application";')
    w("\t\t};")
    w(f"\t\t{I['test_target']} /* {PROJECT}Tests */ = {{")
    w("\t\t\tisa = PBXNativeTarget;")
    w(f"\t\t\tbuildConfigurationList = {I['test_cfgs']} /* Build configuration list for PBXNativeTarget \"{PROJECT}Tests\" */;")
    w(f"\t\t\tbuildPhases = ({I['sources_tests']} /* Sources */, {I['fw_tests']} /* Frameworks */);")
    w("\t\t\tbuildRules = ();")
    w(f"\t\t\tdependencies = ({I['dep']} /* PBXTargetDependency */);")
    w(f"\t\t\tname = {PROJECT}Tests;")
    w(f"\t\t\tproductName = {PROJECT}Tests;")
    w(f"\t\t\tproductReference = {I['test_product']} /* {PROJECT}Tests.xctest */;")
    w('\t\t\tproductType = "com.apple.product-type.bundle.unit-test";')
    w("\t\t};")
    w("/* End PBXNativeTarget section */")
    w("")
    w("/* Begin PBXProject section */")
    w(f"\t\t{I['project']} /* Project object */ = {{")
    w("\t\t\tisa = PBXProject;")
    w("\t\t\tattributes = {")
    w("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    w('\t\t\t\tLastSwiftUpdateCheck = 1610;')
    w("\t\t\t\tLastUpgradeCheck = 1610;")
    w("\t\t\t\tTargetAttributes = {")
    w(f"\t\t\t\t\t{I['app_target']} = {{ CreatedOnToolsVersion = 27.1; }};")
    w(f"\t\t\t\t\t{I['test_target']} = {{ CreatedOnToolsVersion = 27.1; TestTargetID = {I['app_target']}; }};")
    w("\t\t\t\t};")
    w("\t\t\t};")
    w(f"\t\t\tbuildConfigurationList = {I['proj_cfgs']} /* Build configuration list for PBXProject \"{PROJECT}\" */;")
    w('\t\t\tcompatibilityVersion = "Xcode 15.0";')
    w("\t\t\tdevelopmentRegion = en;")
    w("\t\t\thasScannedForEncodings = 0;")
    w("\t\t\tknownRegions = (en, it, Base);")
    w(f"\t\t\tmainGroup = {I['main']};")
    w(f"\t\t\tproductRefGroup = {I['products']} /* Products */;")
    w('\t\t\tprojectDirPath = "";')
    w('\t\t\tprojectRoot = "";')
    w(f"\t\t\ttargets = ({I['app_target']} /* {PROJECT} */, {I['test_target']} /* {PROJECT}Tests */);")
    w("\t\t};")
    w("/* End PBXProject section */")
    w("")
    w("/* Begin PBXResourcesBuildPhase section */")
    w(f"\t\t{I['resources']} /* Resources */ = {{")
    w("\t\t\tisa = PBXResourcesBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w(f"\t\t\tfiles = ({', '.join(resource_builds)});")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w("/* End PBXResourcesBuildPhase section */")
    w("")
    w("/* Begin PBXSourcesBuildPhase section */")
    w(f"\t\t{I['sources_app']} /* Sources */ = {{")
    w("\t\t\tisa = PBXSourcesBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w(f"\t\t\tfiles = ({', '.join(app_source_builds)});")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w(f"\t\t{I['sources_tests']} /* Sources */ = {{")
    w("\t\t\tisa = PBXSourcesBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w(f"\t\t\tfiles = ({', '.join(test_source_builds)});")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w("/* End PBXSourcesBuildPhase section */")
    w("")
    w("/* Begin PBXTargetDependency section */")
    w(f"\t\t{I['dep']} /* PBXTargetDependency */ = {{")
    w("\t\t\tisa = PBXTargetDependency;")
    w(f"\t\t\ttarget = {I['app_target']} /* {PROJECT} */;")
    w(f"\t\t\ttargetProxy = {I['proxy']} /* PBXContainerItemProxy */;")
    w("\t\t};")
    w("/* End PBXTargetDependency section */")
    w("")

    def cfg(cid: str, name: str, body: list[str]) -> None:
        w(f"\t\t{cid} /* {name} */ = {{")
        w("\t\t\tisa = XCBuildConfiguration;")
        w("\t\t\tbuildSettings = {")
        for line in body:
            w(f"\t\t\t\t{line}")
        w("\t\t\t};")
        w(f"\t\t\tname = {name};")
        w("\t\t};")

    common_proj = [
        "ALWAYS_SEARCH_USER_PATHS = NO;",
        "CLANG_ENABLE_MODULES = YES;",
        "CLANG_ENABLE_OBJC_ARC = YES;",
        "COPY_PHASE_STRIP = NO;",
        "DEAD_CODE_STRIPPING = YES;",
        f"MACOSX_DEPLOYMENT_TARGET = {DEPLOYMENT};",
        "SDKROOT = macosx;",
        "STRING_CATALOG_GENERATE_SYMBOLS = YES;",
        "SWIFT_VERSION = 6.0;",
    ]
    debug_extra = [
        "DEBUG_INFORMATION_FORMAT = dwarf;",
        "ENABLE_TESTABILITY = YES;",
        "GCC_DYNAMIC_NO_PIC = NO;",
        "GCC_OPTIMIZATION_LEVEL = 0;",
        "GCC_PREPROCESSOR_DEFINITIONS = (\"DEBUG=1\", \"$(inherited)\");",
        "ONLY_ACTIVE_ARCH = YES;",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\";",
        "SWIFT_OPTIMIZATION_LEVEL = \"-Onone\";",
    ]
    release_extra = [
        "DEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";",
        "ENABLE_NS_ASSERTIONS = NO;",
        "SWIFT_COMPILATION_MODE = wholemodule;",
    ]

    w("/* Begin XCBuildConfiguration section */")
    cfg(I["dbg_proj"], "Debug", common_proj + debug_extra)
    cfg(I["rel_proj"], "Release", common_proj + release_extra)

    app_settings = [
        "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;",
        "CODE_SIGN_ENTITLEMENTS = MacExplorer/MacExplorer.entitlements;",
        "CODE_SIGN_STYLE = Automatic;",
        "COMBINE_HIDPI_IMAGES = YES;",
        "CURRENT_PROJECT_VERSION = 1;",
        "ENABLE_HARDENED_RUNTIME = YES;",
        "GENERATE_INFOPLIST_FILE = NO;",
        "INFOPLIST_FILE = MacExplorer/Info.plist;",
        "LD_RUNPATH_SEARCH_PATHS = (\"$(inherited)\", \"@executable_path/../Frameworks\");",
        "MARKETING_VERSION = 1.0.0;",
        f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};",
        "PRODUCT_NAME = \"$(TARGET_NAME)\";",
        "SWIFT_EMIT_LOC_STRINGS = YES;",
        "SWIFT_STRICT_CONCURRENCY = complete;",
    ]
    cfg(I["dbg_app"], "Debug", app_settings + ["ENABLE_TESTABILITY = YES;"])
    cfg(I["rel_app"], "Release", app_settings)

    test_settings = [
        "BUNDLE_LOADER = \"$(TEST_HOST)\";",
        "CODE_SIGN_STYLE = Automatic;",
        "CURRENT_PROJECT_VERSION = 1;",
        "GENERATE_INFOPLIST_FILE = YES;",
        "MARKETING_VERSION = 1.0.0;",
        f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}.tests;",
        "PRODUCT_NAME = \"$(TARGET_NAME)\";",
        "SWIFT_EMIT_LOC_STRINGS = NO;",
        "SWIFT_STRICT_CONCURRENCY = complete;",
        f"TEST_HOST = \"$(BUILT_PRODUCTS_DIR)/{PROJECT}.app/Contents/MacOS/{PROJECT}\";",
    ]
    cfg(I["dbg_test"], "Debug", test_settings)
    cfg(I["rel_test"], "Release", test_settings)
    w("/* End XCBuildConfiguration section */")
    w("")

    w("/* Begin XCConfigurationList section */")
    for cid, name, dbg, rel in [
        (I["proj_cfgs"], f"PBXProject \"{PROJECT}\"", I["dbg_proj"], I["rel_proj"]),
        (I["app_cfgs"], f"PBXNativeTarget \"{PROJECT}\"", I["dbg_app"], I["rel_app"]),
        (I["test_cfgs"], f"PBXNativeTarget \"{PROJECT}Tests\"", I["dbg_test"], I["rel_test"]),
    ]:
        w(f"\t\t{cid} /* Build configuration list for {name} */ = {{")
        w("\t\t\tisa = XCConfigurationList;")
        w(f"\t\t\tbuildConfigurations = ({dbg} /* Debug */, {rel} /* Release */);")
        w("\t\t\tdefaultConfigurationIsVisible = 0;")
        w("\t\t\tdefaultConfigurationName = Release;")
        w("\t\t};")
    w("/* End XCConfigurationList section */")
    w("\t};")
    w(f"\trootObject = {I['project']} /* Project object */;")
    w("}")

    out_dir = ROOT / f"{PROJECT}.xcodeproj"
    out_dir.mkdir(exist_ok=True)
    (out_dir / "project.pbxproj").write_text("\n".join(lines) + "\n", encoding="utf-8")
    scheme_dir = out_dir / "xcshareddata" / "xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    (scheme_dir / f"{PROJECT}.xcscheme").write_text(
        f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1610"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{I['app_target']}"
               BuildableName = "{PROJECT}.app"
               BlueprintName = "{PROJECT}"
               ReferencedContainer = "container:{PROJECT}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
      <Testables>
         <TestableReference
            skipped = "NO"
            parallelizable = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{I['test_target']}"
               BuildableName = "{PROJECT}Tests.xctest"
               BlueprintName = "{PROJECT}Tests"
               ReferencedContainer = "container:{PROJECT}.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{I['app_target']}"
            BuildableName = "{PROJECT}.app"
            BlueprintName = "{PROJECT}"
            ReferencedContainer = "container:{PROJECT}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{I['app_target']}"
            BuildableName = "{PROJECT}.app"
            BlueprintName = "{PROJECT}"
            ReferencedContainer = "container:{PROJECT}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
""",
        encoding="utf-8",
    )
    print(f"Wrote {out_dir / 'project.pbxproj'}")
    print(f"App sources: {len(app_swifts)}, tests: {len(test_swifts)}")


if __name__ == "__main__":
    app_dir = ROOT / "MacExplorer"
    tests_dir = ROOT / "MacExplorerTests"
    write_final(
        sorted(app_dir.rglob("*.swift")),
        sorted(tests_dir.rglob("*.swift")),
        app_dir / "Assets.xcassets",
        None,
        sorted(app_dir.rglob("*.strings")),
        app_dir / "MacExplorer.entitlements",
        app_dir / "Info.plist",
        app_dir,
        tests_dir,
    )
