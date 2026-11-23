#!/usr/bin/env python3
"""
Generates L4NETraining.xcodeproj for macOS & iOS development in Xcode,
linking directly against target/release/libl4ne_core.a and crates/l4ne-core/include/l4ne_core.h.
"""
import os
import uuid
from pathlib import Path

def generate_pbxproj():
    base_dir = Path(__file__).resolve().parent
    source_dirs = [
        base_dir / "Sources" / "L4NETrainingCore",
        base_dir / "Sources" / "L4NETrainingUI",
        base_dir / "Sources" / "L4NETrainingApp",
    ]

    swift_files = []
    for sdir in source_dirs:
        for root, _, files in os.walk(sdir):
            for f in sorted(files):
                if f.endswith(".swift"):
                    swift_files.append((Path(root) / f, f))

    def make_id(seed: str) -> str:
        return uuid.uuid5(uuid.NAMESPACE_DNS, seed).hex[:24].upper()

    file_refs = []
    build_files = []
    children_ids = []

    for path, name in swift_files:
        rel_path = path.relative_to(base_dir)
        fid = make_id(f"fileref_{rel_path}")
        bid = make_id(f"buildfile_{rel_path}")
        file_refs.append(
            f'\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{rel_path}"; sourceTree = "<group>"; }};'
        )
        build_files.append(
            f'\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};'
        )
        children_ids.append(f"\t\t\t\t{fid} /* {name} */,")

    target_id = make_id("target_L4NETraining")
    config_debug_id = make_id("config_debug")
    config_release_id = make_id("config_release")
    config_list_id = make_id("config_list")
    proj_config_debug_id = make_id("proj_config_debug")
    proj_config_release_id = make_id("proj_config_release")
    proj_config_list_id = make_id("proj_config_list")
    sources_build_phase_id = make_id("sources_build_phase")
    resources_build_phase_id = make_id("resources_build_phase")
    xcassets_fileref_id = make_id("fileref_xcassets")
    xcassets_buildfile_id = make_id("buildfile_xcassets")
    main_group_id = make_id("main_group")
    proj_id = make_id("project_root")
    product_id = make_id("product_app")

    file_refs.append(
        f'\t\t{xcassets_fileref_id} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = "Sources/L4NETrainingApp/Assets.xcassets"; sourceTree = "<group>"; }};'
    )
    build_files.append(
        f'\t\t{xcassets_buildfile_id} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {xcassets_fileref_id} /* Assets.xcassets */; }};'
    )
    children_ids.append(f"\t\t\t\t{xcassets_fileref_id} /* Assets.xcassets */,")

    sources_phase_entries = "\n".join(
        [
            f'\t\t\t\t{make_id(f"buildfile_{p.relative_to(base_dir)}")} /* {n} in Sources */,'
            for p, n in swift_files
        ]
    )

    pbx = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_files)}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{chr(10).join(file_refs)}
		{product_id} /* L4NETraining.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = L4NETraining.app; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section */

/* Begin PBXGroup section */
		{main_group_id} = {{
			isa = PBXGroup;
			children = (
{chr(10).join(children_ids)}
				{product_id} /* L4NETraining.app */,
			);
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{target_id} /* L4NETraining */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {config_list_id} /* Build configuration list for PBXNativeTarget "L4NETraining" */;
			buildPhases = (
				{sources_build_phase_id} /* Sources */,
				{resources_build_phase_id} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = L4NETraining;
			productName = L4NETraining;
			productReference = {product_id} /* L4NETraining.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{proj_id} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1600;
				LastUpgradeCheck = 1600;
			}};
			buildConfigurationList = {proj_config_list_id} /* Build configuration list for PBXProject "L4NETraining" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = el;
			hasScannedForEncodings = 0;
			knownRegions = (
				el,
				en,
			);
			mainGroup = {main_group_id};
			productRefGroup = {main_group_id};
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{target_id} /* L4NETraining */,
			);
		}};
/* End PBXProject section */

/* Begin PBXSourcesBuildPhase section */
		{sources_build_phase_id} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{sources_phase_entries}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin PBXResourcesBuildPhase section */
		{resources_build_phase_id} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{xcassets_buildfile_id} /* Assets.xcassets in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{proj_config_debug_id} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				MARKETING_VERSION = 1.3.0;
				CURRENT_PROJECT_VERSION = 4;
				SWIFT_VERSION = 5.0;
			}};
			name = Debug;
		}};
		{proj_config_release_id} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				MARKETING_VERSION = 1.3.0;
				CURRENT_PROJECT_VERSION = 4;
				SWIFT_VERSION = 5.0;
			}};
			name = Release;
		}};
		{config_debug_id} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = "L4NE Performance";
				INFOPLIST_KEY_NSHealthShareUsageDescription = "Το L4NE Performance διαβάζει προαιρετικά προπονήσεις, καρδιακή συχνότητα, ύπνο και HRV από το Apple Health για ανάλυση απόδοσης.";
				INFOPLIST_KEY_NSHealthUpdateUsageDescription = "Το L4NE Performance αποθηκεύει προαιρετικά τις καταγεγραμμένες προπονήσεις σου στο Apple Health ως HKWorkout.";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				LIBRARY_SEARCH_PATHS = (
					"$(inherited)",
					"$(PROJECT_DIR)/target/release",
				);
				OTHER_LDFLAGS = (
					"$(PROJECT_DIR)/target/release/libl4ne_core.a",
				);
				"OTHER_LDFLAGS[sdk=iphonesimulator*]" = (
					"$(PROJECT_DIR)/target/release/libl4ne_core_iossim.a",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.l4ne.training;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx";
				SWIFT_OBJC_BRIDGING_HEADER = "$(PROJECT_DIR)/crates/l4ne-core/include/l4ne_core.h";
			}};
			name = Debug;
		}};
		{config_release_id} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = "L4NE Performance";
				INFOPLIST_KEY_NSHealthShareUsageDescription = "Το L4NE Performance διαβάζει προαιρετικά προπονήσεις, καρδιακή συχνότητα, ύπνο και HRV από το Apple Health για ανάλυση απόδοσης.";
				INFOPLIST_KEY_NSHealthUpdateUsageDescription = "Το L4NE Performance αποθηκεύει προαιρετικά τις καταγεγραμμένες προπονήσεις σου στο Apple Health ως HKWorkout.";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				LIBRARY_SEARCH_PATHS = (
					"$(inherited)",
					"$(PROJECT_DIR)/target/release",
				);
				OTHER_LDFLAGS = (
					"$(PROJECT_DIR)/target/release/libl4ne_core.a",
				);
				"OTHER_LDFLAGS[sdk=iphonesimulator*]" = (
					"$(PROJECT_DIR)/target/release/libl4ne_core_iossim.a",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.l4ne.training;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx";
				SWIFT_OBJC_BRIDGING_HEADER = "$(PROJECT_DIR)/crates/l4ne-core/include/l4ne_core.h";
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{proj_config_list_id} /* Build configuration list for PBXProject "L4NETraining" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{proj_config_debug_id} /* Debug */,
				{proj_config_release_id} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{config_list_id} /* Build configuration list for PBXNativeTarget "L4NETraining" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{config_debug_id} /* Debug */,
				{config_release_id} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {proj_id} /* Project object */;
}}
"""
    proj_dir = base_dir / "L4NETraining.xcodeproj"
    proj_dir.mkdir(exist_ok=True)
    (proj_dir / "project.pbxproj").write_text(pbx, encoding="utf-8")
    print(f"Generated {proj_dir / 'project.pbxproj'}")

if __name__ == "__main__":
    generate_pbxproj()
