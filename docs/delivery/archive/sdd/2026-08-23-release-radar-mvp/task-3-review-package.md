# Review package: ac3675258c9f0e7e581af975bd46288bfa95fac7..HEAD

## Commits
d393dbf docs: record RR-03 transport proof
fa8eea0 feat: add signed agent bridge transport
8f02b9a docs: record RR-03 transport blocker
6b7262c feat: add typed agent delivery actions

## Files changed
 ReleaseRadar.xcodeproj/project.pbxproj             |  57 ++-
 ReleaseRadar/App/ReleaseRadarApp.swift             |  32 ++
 ReleaseRadar/ReleaseRadar.entitlements             |   4 +
 ReleaseRadarAgentTools/main.swift                  | 384 ++++++++++++++++++++-
 .../ReleaseRadarBridgeAgent.entitlements           |  12 +
 .../com.rekonlabs.ReleaseRadar.BridgeAgent.plist   |  17 +
 ReleaseRadarBridgeAgent/main.swift                 | 179 ++++++++++
 ReleaseRadarCore/AgentBridge/AgentCommand.swift    | 105 ++++++
 .../AgentBridge/AgentCommandDispatcher.swift       | 377 ++++++++++++++++++++
 ReleaseRadarCore/Models/DeliveryModels.swift       |  16 +-
 ReleaseRadarCore/Store/DeliveryStore.swift         |  19 +-
 ReleaseRadarCore/Store/StoreMigrations.swift       |  33 +-
 .../AgentBridgeApplicationHost.swift               | 266 ++++++++++++++
 ReleaseRadarTests/AgentBridgeAcceptanceTests.swift | 311 +++++++++++++++++
 .../AgentBridgeTransportAcceptanceTests.swift      | 229 ++++++++++++
 ReleaseRadarTests/StoreAcceptanceTests.swift       |   2 +-
 ReleaseRadarTransport/BridgeXPCContracts.swift     |  82 +++++
 docs/delivery/progress.md                          |  21 +-
 18 files changed, 2125 insertions(+), 21 deletions(-)

## Diff
diff --git a/ReleaseRadar.xcodeproj/project.pbxproj b/ReleaseRadar.xcodeproj/project.pbxproj
index f6ce46a..350d77f 100644
--- a/ReleaseRadar.xcodeproj/project.pbxproj
+++ b/ReleaseRadar.xcodeproj/project.pbxproj
@@ -3,20 +3,23 @@
 	archiveVersion = 1;
 	classes = {
 	};
 	objectVersion = 77;
 	objects = {
 
 /* Begin PBXBuildFile section */
 		B10000000000000000000001 /* ReleaseRadarCore.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = A10000000000000000000011 /* ReleaseRadarCore.framework */; };
 		B10000000000000000000002 /* ReleaseRadarCore.framework in Embed Frameworks */ = {isa = PBXBuildFile; fileRef = A10000000000000000000011 /* ReleaseRadarCore.framework */; settings = {ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }; };
 		B10000000000000000000003 /* ReleaseRadarCore.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = A10000000000000000000011 /* ReleaseRadarCore.framework */; };
+		B10000000000000000000004 /* ReleaseRadarBridgeAgent in Copy Bridge Agent */ = {isa = PBXBuildFile; fileRef = A10000000000000000000015 /* ReleaseRadarBridgeAgent */; settings = {ATTRIBUTES = (CodeSignOnCopy, ); }; };
+		B10000000000000000000005 /* ReleaseRadarAgentTools in Copy Helpers */ = {isa = PBXBuildFile; fileRef = A10000000000000000000012 /* ReleaseRadarAgentTools */; settings = {ATTRIBUTES = (CodeSignOnCopy, ); }; };
+		B10000000000000000000006 /* com.rekonlabs.ReleaseRadar.BridgeAgent.plist in Copy LaunchAgents */ = {isa = PBXBuildFile; fileRef = A10000000000000000000017 /* com.rekonlabs.ReleaseRadar.BridgeAgent.plist */; };
 /* End PBXBuildFile section */
 
 /* Begin PBXContainerItemProxy section */
 		A70000000000000000000001 /* PBXContainerItemProxy */ = {
 			isa = PBXContainerItemProxy;
 			containerPortal = A30000000000000000000001 /* Project object */;
 			proxyType = 1;
 			remoteGlobalIDString = A20000000000000000000002;
 			remoteInfo = ReleaseRadarCore;
 		};
@@ -34,106 +37,127 @@
 			remoteGlobalIDString = A20000000000000000000002;
 			remoteInfo = ReleaseRadarCore;
 		};
 		A70000000000000000000004 /* PBXContainerItemProxy */ = {
 			isa = PBXContainerItemProxy;
 			containerPortal = A30000000000000000000001 /* Project object */;
 			proxyType = 1;
 			remoteGlobalIDString = A20000000000000000000001;
 			remoteInfo = ReleaseRadar;
 		};
+		A70000000000000000000005 /* PBXContainerItemProxy */ = {isa = PBXContainerItemProxy; containerPortal = A30000000000000000000001 /* Project object */; proxyType = 1; remoteGlobalIDString = A20000000000000000000006; remoteInfo = ReleaseRadarBridgeAgent; };
+		A70000000000000000000006 /* PBXContainerItemProxy */ = {isa = PBXContainerItemProxy; containerPortal = A30000000000000000000001 /* Project object */; proxyType = 1; remoteGlobalIDString = A20000000000000000000003; remoteInfo = ReleaseRadarAgentTools; };
+		A70000000000000000000007 /* PBXContainerItemProxy */ = {isa = PBXContainerItemProxy; containerPortal = A30000000000000000000001 /* Project object */; proxyType = 1; remoteGlobalIDString = A20000000000000000000007; remoteInfo = ReleaseRadarWrongAgentTools; };
 /* End PBXContainerItemProxy section */
 
 /* Begin PBXCopyFilesBuildPhase section */
 		C10000000000000000000004 /* Embed Frameworks */ = {
 			isa = PBXCopyFilesBuildPhase;
 			buildActionMask = 2147483647;
 			dstPath = "";
 			dstSubfolderSpec = 10;
 			files = (
 				B10000000000000000000002 /* ReleaseRadarCore.framework in Embed Frameworks */,
 			);
 			name = "Embed Frameworks";
 			runOnlyForDeploymentPostprocessing = 0;
 		};
+		C10000000000000000000005 /* Copy Bridge Agent */ = {isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = Contents/Resources; dstSubfolderSpec = 1; files = (B10000000000000000000004 /* ReleaseRadarBridgeAgent in Copy Bridge Agent */, ); name = "Copy Bridge Agent"; runOnlyForDeploymentPostprocessing = 0; };
+		C10000000000000000000006 /* Copy LaunchAgents */ = {isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = Contents/Library/LaunchAgents; dstSubfolderSpec = 1; files = (B10000000000000000000006 /* com.rekonlabs.ReleaseRadar.BridgeAgent.plist in Copy LaunchAgents */, ); name = "Copy LaunchAgents"; runOnlyForDeploymentPostprocessing = 0; };
+		C10000000000000000000007 /* Copy Helpers */ = {isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = Contents/Helpers; dstSubfolderSpec = 1; files = (B10000000000000000000005 /* ReleaseRadarAgentTools in Copy Helpers */, ); name = "Copy Helpers"; runOnlyForDeploymentPostprocessing = 0; };
 /* End PBXCopyFilesBuildPhase section */
 
 /* Begin PBXFileReference section */
 		A10000000000000000000010 /* ReleaseRadar.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = ReleaseRadar.app; sourceTree = BUILT_PRODUCTS_DIR; };
 		A10000000000000000000011 /* ReleaseRadarCore.framework */ = {isa = PBXFileReference; explicitFileType = wrapper.framework; includeInIndex = 0; path = ReleaseRadarCore.framework; sourceTree = BUILT_PRODUCTS_DIR; };
 		A10000000000000000000012 /* ReleaseRadarAgentTools */ = {isa = PBXFileReference; explicitFileType = "compiled.mach-o.executable"; includeInIndex = 0; path = ReleaseRadarAgentTools; sourceTree = BUILT_PRODUCTS_DIR; };
 		A10000000000000000000013 /* ReleaseRadarTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = ReleaseRadarTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
 		A10000000000000000000014 /* ReleaseRadarUITests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = ReleaseRadarUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
+		A10000000000000000000015 /* ReleaseRadarBridgeAgent */ = {isa = PBXFileReference; explicitFileType = "compiled.mach-o.executable"; includeInIndex = 0; path = ReleaseRadarBridgeAgent; sourceTree = BUILT_PRODUCTS_DIR; };
+		A10000000000000000000016 /* ReleaseRadarWrongAgentTools */ = {isa = PBXFileReference; explicitFileType = "compiled.mach-o.executable"; includeInIndex = 0; path = ReleaseRadarWrongAgentTools; sourceTree = BUILT_PRODUCTS_DIR; };
+		A10000000000000000000017 /* com.rekonlabs.ReleaseRadar.BridgeAgent.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = ReleaseRadarBridgeAgent/com.rekonlabs.ReleaseRadar.BridgeAgent.plist; sourceTree = SOURCE_ROOT; };
 /* End PBXFileReference section */
 
 /* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */
 		A90000000000000000000001 /* Exceptions for ReleaseRadar folder in ReleaseRadar target */ = {
 			isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
 			membershipExceptions = (
 				Info.plist,
 				ReleaseRadar.entitlements,
 			);
 			target = A20000000000000000000001 /* ReleaseRadar */;
 		};
+		A90000000000000000000002 /* Exceptions for ReleaseRadarBridgeAgent folder in ReleaseRadarBridgeAgent target */ = {isa = PBXFileSystemSynchronizedBuildFileExceptionSet; membershipExceptions = (ReleaseRadarBridgeAgent.entitlements, com.rekonlabs.ReleaseRadar.BridgeAgent.plist, ); target = A20000000000000000000006 /* ReleaseRadarBridgeAgent */; };
 /* End PBXFileSystemSynchronizedBuildFileExceptionSet section */
 
 /* Begin PBXFileSystemSynchronizedRootGroup section */
 		A10000000000000000000003 /* ReleaseRadar */ = {isa = PBXFileSystemSynchronizedRootGroup; exceptions = (A90000000000000000000001 /* Exceptions for ReleaseRadar folder in ReleaseRadar target */, ); path = ReleaseRadar; sourceTree = "<group>"; };
 		A10000000000000000000004 /* ReleaseRadarCore */ = {isa = PBXFileSystemSynchronizedRootGroup; path = ReleaseRadarCore; sourceTree = "<group>"; };
 		A10000000000000000000005 /* ReleaseRadarAgentTools */ = {isa = PBXFileSystemSynchronizedRootGroup; path = ReleaseRadarAgentTools; sourceTree = "<group>"; };
 		A10000000000000000000006 /* ReleaseRadarTests */ = {isa = PBXFileSystemSynchronizedRootGroup; path = ReleaseRadarTests; sourceTree = "<group>"; };
 		A10000000000000000000007 /* ReleaseRadarUITests */ = {isa = PBXFileSystemSynchronizedRootGroup; path = ReleaseRadarUITests; sourceTree = "<group>"; };
+		A10000000000000000000008 /* ReleaseRadarIntegration */ = {isa = PBXFileSystemSynchronizedRootGroup; path = ReleaseRadarIntegration; sourceTree = "<group>"; };
+		A10000000000000000000009 /* ReleaseRadarTransport */ = {isa = PBXFileSystemSynchronizedRootGroup; path = ReleaseRadarTransport; sourceTree = "<group>"; };
+		A1000000000000000000000A /* ReleaseRadarBridgeAgent */ = {isa = PBXFileSystemSynchronizedRootGroup; exceptions = (A90000000000000000000002 /* Exceptions for ReleaseRadarBridgeAgent folder in ReleaseRadarBridgeAgent target */, ); path = ReleaseRadarBridgeAgent; sourceTree = "<group>"; };
 /* End PBXFileSystemSynchronizedRootGroup section */
 
 /* Begin PBXFrameworksBuildPhase section */
 		C10000000000000000000002 /* Frameworks */ = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (B10000000000000000000001 /* ReleaseRadarCore.framework in Frameworks */, ); runOnlyForDeploymentPostprocessing = 0; };
 		C11000000000000000000002 /* Frameworks */ = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
 		C12000000000000000000002 /* Frameworks */ = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
 		C13000000000000000000002 /* Frameworks */ = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (B10000000000000000000003 /* ReleaseRadarCore.framework in Frameworks */, ); runOnlyForDeploymentPostprocessing = 0; };
 		C14000000000000000000002 /* Frameworks */ = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
+		C15000000000000000000002 /* Frameworks */ = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
+		C16000000000000000000002 /* Frameworks */ = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
 /* End PBXFrameworksBuildPhase section */
 
 /* Begin PBXGroup section */
 		A10000000000000000000001 = {
 			isa = PBXGroup;
 			children = (
 				A10000000000000000000003 /* ReleaseRadar */,
 				A10000000000000000000004 /* ReleaseRadarCore */,
 				A10000000000000000000005 /* ReleaseRadarAgentTools */,
 				A10000000000000000000006 /* ReleaseRadarTests */,
 				A10000000000000000000007 /* ReleaseRadarUITests */,
+				A10000000000000000000008 /* ReleaseRadarIntegration */,
+				A10000000000000000000009 /* ReleaseRadarTransport */,
+				A1000000000000000000000A /* ReleaseRadarBridgeAgent */,
+				A10000000000000000000017 /* com.rekonlabs.ReleaseRadar.BridgeAgent.plist */,
 				A10000000000000000000002 /* Products */,
 			);
 			sourceTree = "<group>";
 		};
 		A10000000000000000000002 /* Products */ = {
 			isa = PBXGroup;
 			children = (
 				A10000000000000000000010 /* ReleaseRadar.app */,
 				A10000000000000000000011 /* ReleaseRadarCore.framework */,
 				A10000000000000000000012 /* ReleaseRadarAgentTools */,
 				A10000000000000000000013 /* ReleaseRadarTests.xctest */,
 				A10000000000000000000014 /* ReleaseRadarUITests.xctest */,
+				A10000000000000000000015 /* ReleaseRadarBridgeAgent */,
+				A10000000000000000000016 /* ReleaseRadarWrongAgentTools */,
 			);
 			name = Products;
 			sourceTree = "<group>";
 		};
 /* End PBXGroup section */
 
 /* Begin PBXNativeTarget section */
 		A20000000000000000000001 /* ReleaseRadar */ = {
 			isa = PBXNativeTarget;
 			buildConfigurationList = A50000000000000000000055 /* Build configuration list for PBXNativeTarget "ReleaseRadar" */;
-			buildPhases = (C10000000000000000000001 /* Sources */, C10000000000000000000002 /* Frameworks */, C10000000000000000000003 /* Resources */, C10000000000000000000004 /* Embed Frameworks */, );
+			buildPhases = (C10000000000000000000001 /* Sources */, C10000000000000000000002 /* Frameworks */, C10000000000000000000003 /* Resources */, C10000000000000000000004 /* Embed Frameworks */, C10000000000000000000005 /* Copy Bridge Agent */, C10000000000000000000006 /* Copy LaunchAgents */, C10000000000000000000007 /* Copy Helpers */, );
 			buildRules = ();
-			dependencies = (A80000000000000000000001 /* PBXTargetDependency */, );
-			fileSystemSynchronizedGroups = (A10000000000000000000003 /* ReleaseRadar */, );
+			dependencies = (A80000000000000000000001 /* PBXTargetDependency */, A80000000000000000000005 /* PBXTargetDependency */, A80000000000000000000006 /* PBXTargetDependency */, );
+			fileSystemSynchronizedGroups = (A10000000000000000000003 /* ReleaseRadar */, A10000000000000000000008 /* ReleaseRadarIntegration */, A10000000000000000000009 /* ReleaseRadarTransport */, );
 			name = ReleaseRadar;
 			packageProductDependencies = ();
 			productName = ReleaseRadar;
 			productReference = A10000000000000000000010 /* ReleaseRadar.app */;
 			productType = "com.apple.product-type.application";
 		};
 		A20000000000000000000002 /* ReleaseRadarCore */ = {
 			isa = PBXNativeTarget;
 			buildConfigurationList = A50000000000000000000058 /* Build configuration list for PBXNativeTarget "ReleaseRadarCore" */;
 			buildPhases = (C11000000000000000000001 /* Sources */, C11000000000000000000002 /* Frameworks */, C11000000000000000000003 /* Resources */, );
@@ -145,123 +169,140 @@
 			productName = ReleaseRadarCore;
 			productReference = A10000000000000000000011 /* ReleaseRadarCore.framework */;
 			productType = "com.apple.product-type.framework";
 		};
 		A20000000000000000000003 /* ReleaseRadarAgentTools */ = {
 			isa = PBXNativeTarget;
 			buildConfigurationList = A5000000000000000000005B /* Build configuration list for PBXNativeTarget "ReleaseRadarAgentTools" */;
 			buildPhases = (C12000000000000000000001 /* Sources */, C12000000000000000000002 /* Frameworks */, C12000000000000000000003 /* Resources */, );
 			buildRules = ();
 			dependencies = ();
-			fileSystemSynchronizedGroups = (A10000000000000000000005 /* ReleaseRadarAgentTools */, );
+			fileSystemSynchronizedGroups = (A10000000000000000000005 /* ReleaseRadarAgentTools */, A10000000000000000000009 /* ReleaseRadarTransport */, );
 			name = ReleaseRadarAgentTools;
 			packageProductDependencies = ();
 			productName = ReleaseRadarAgentTools;
 			productReference = A10000000000000000000012 /* ReleaseRadarAgentTools */;
 			productType = "com.apple.product-type.tool";
 		};
 		A20000000000000000000004 /* ReleaseRadarTests */ = {
 			isa = PBXNativeTarget;
 			buildConfigurationList = A5000000000000000000005E /* Build configuration list for PBXNativeTarget "ReleaseRadarTests" */;
 			buildPhases = (C13000000000000000000001 /* Sources */, C13000000000000000000002 /* Frameworks */, C13000000000000000000003 /* Resources */, );
 			buildRules = ();
-			dependencies = (A80000000000000000000002 /* PBXTargetDependency */, A80000000000000000000003 /* PBXTargetDependency */, );
+			dependencies = (A80000000000000000000002 /* PBXTargetDependency */, A80000000000000000000003 /* PBXTargetDependency */, A80000000000000000000007 /* PBXTargetDependency */, );
 			fileSystemSynchronizedGroups = (A10000000000000000000006 /* ReleaseRadarTests */, );
 			name = ReleaseRadarTests;
 			packageProductDependencies = ();
 			productName = ReleaseRadarTests;
 			productReference = A10000000000000000000013 /* ReleaseRadarTests.xctest */;
 			productType = "com.apple.product-type.bundle.unit-test";
 		};
 		A20000000000000000000005 /* ReleaseRadarUITests */ = {
 			isa = PBXNativeTarget;
 			buildConfigurationList = A50000000000000000000061 /* Build configuration list for PBXNativeTarget "ReleaseRadarUITests" */;
 			buildPhases = (C14000000000000000000001 /* Sources */, C14000000000000000000002 /* Frameworks */, C14000000000000000000003 /* Resources */, );
 			buildRules = ();
 			dependencies = (A80000000000000000000004 /* PBXTargetDependency */, );
 			fileSystemSynchronizedGroups = (A10000000000000000000007 /* ReleaseRadarUITests */, );
 			name = ReleaseRadarUITests;
 			packageProductDependencies = ();
 			productName = ReleaseRadarUITests;
 			productReference = A10000000000000000000014 /* ReleaseRadarUITests.xctest */;
 			productType = "com.apple.product-type.bundle.ui-testing";
 		};
+		A20000000000000000000006 /* ReleaseRadarBridgeAgent */ = {isa = PBXNativeTarget; buildConfigurationList = A50000000000000000000064 /* Build configuration list for PBXNativeTarget "ReleaseRadarBridgeAgent" */; buildPhases = (C15000000000000000000001 /* Sources */, C15000000000000000000002 /* Frameworks */, C15000000000000000000003 /* Resources */, ); buildRules = (); dependencies = (); fileSystemSynchronizedGroups = (A1000000000000000000000A /* ReleaseRadarBridgeAgent */, A10000000000000000000009 /* ReleaseRadarTransport */, ); name = ReleaseRadarBridgeAgent; packageProductDependencies = (); productName = ReleaseRadarBridgeAgent; productReference = A10000000000000000000015 /* ReleaseRadarBridgeAgent */; productType = "com.apple.product-type.tool"; };
+		A20000000000000000000007 /* ReleaseRadarWrongAgentTools */ = {isa = PBXNativeTarget; buildConfigurationList = A50000000000000000000067 /* Build configuration list for PBXNativeTarget "ReleaseRadarWrongAgentTools" */; buildPhases = (C16000000000000000000001 /* Sources */, C16000000000000000000002 /* Frameworks */, C16000000000000000000003 /* Resources */, ); buildRules = (); dependencies = (); fileSystemSynchronizedGroups = (A10000000000000000000005 /* ReleaseRadarAgentTools */, A10000000000000000000009 /* ReleaseRadarTransport */, ); name = ReleaseRadarWrongAgentTools; packageProductDependencies = (); productName = ReleaseRadarWrongAgentTools; productReference = A10000000000000000000016 /* ReleaseRadarWrongAgentTools */; productType = "com.apple.product-type.tool"; };
 /* End PBXNativeTarget section */
 
 /* Begin PBXProject section */
 		A30000000000000000000001 /* Project object */ = {
 			isa = PBXProject;
 			attributes = {
 				BuildIndependentTargetsInParallel = 1;
 				LastSwiftUpdateCheck = 2660;
 				LastUpgradeCheck = 2660;
 				TargetAttributes = {
 					A20000000000000000000001 = {CreatedOnToolsVersion = 26.6; };
 					A20000000000000000000002 = {CreatedOnToolsVersion = 26.6; };
 					A20000000000000000000003 = {CreatedOnToolsVersion = 26.6; };
 					A20000000000000000000004 = {CreatedOnToolsVersion = 26.6; TestTargetID = A20000000000000000000001; };
 					A20000000000000000000005 = {CreatedOnToolsVersion = 26.6; TestTargetID = A20000000000000000000001; };
+					A20000000000000000000006 = {CreatedOnToolsVersion = 26.6; };
+					A20000000000000000000007 = {CreatedOnToolsVersion = 26.6; };
 				};
 			};
 			buildConfigurationList = A50000000000000000000052 /* Build configuration list for PBXProject "ReleaseRadar" */;
 			developmentRegion = en;
 			hasScannedForEncodings = 0;
 			knownRegions = (en, Base, );
 			mainGroup = A10000000000000000000001;
 			minimizedProjectReferenceProxies = 1;
 			preferredProjectObjectVersion = 77;
 			productRefGroup = A10000000000000000000002 /* Products */;
 			projectDirPath = "";
 			projectRoot = "";
-			targets = (A20000000000000000000001 /* ReleaseRadar */, A20000000000000000000002 /* ReleaseRadarCore */, A20000000000000000000003 /* ReleaseRadarAgentTools */, A20000000000000000000004 /* ReleaseRadarTests */, A20000000000000000000005 /* ReleaseRadarUITests */, );
+			targets = (A20000000000000000000001 /* ReleaseRadar */, A20000000000000000000002 /* ReleaseRadarCore */, A20000000000000000000003 /* ReleaseRadarAgentTools */, A20000000000000000000004 /* ReleaseRadarTests */, A20000000000000000000005 /* ReleaseRadarUITests */, A20000000000000000000006 /* ReleaseRadarBridgeAgent */, A20000000000000000000007 /* ReleaseRadarWrongAgentTools */, );
 		};
 /* End PBXProject section */
 
 /* Begin PBXResourcesBuildPhase section */
 		C10000000000000000000003 /* Resources */ = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
 		C11000000000000000000003 /* Resources */ = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
 		C12000000000000000000003 /* Resources */ = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
 		C13000000000000000000003 /* Resources */ = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
 		C14000000000000000000003 /* Resources */ = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
+		C15000000000000000000003 /* Resources */ = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
+		C16000000000000000000003 /* Resources */ = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
 /* End PBXResourcesBuildPhase section */
 
 /* Begin PBXSourcesBuildPhase section */
 		C10000000000000000000001 /* Sources */ = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
 		C11000000000000000000001 /* Sources */ = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
 		C12000000000000000000001 /* Sources */ = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
 		C13000000000000000000001 /* Sources */ = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
 		C14000000000000000000001 /* Sources */ = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
+		C15000000000000000000001 /* Sources */ = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
+		C16000000000000000000001 /* Sources */ = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
 /* End PBXSourcesBuildPhase section */
 
 /* Begin PBXTargetDependency section */
 		A80000000000000000000001 /* PBXTargetDependency */ = {isa = PBXTargetDependency; target = A20000000000000000000002 /* ReleaseRadarCore */; targetProxy = A70000000000000000000001 /* PBXContainerItemProxy */; };
 		A80000000000000000000002 /* PBXTargetDependency */ = {isa = PBXTargetDependency; target = A20000000000000000000001 /* ReleaseRadar */; targetProxy = A70000000000000000000002 /* PBXContainerItemProxy */; };
 		A80000000000000000000003 /* PBXTargetDependency */ = {isa = PBXTargetDependency; target = A20000000000000000000002 /* ReleaseRadarCore */; targetProxy = A70000000000000000000003 /* PBXContainerItemProxy */; };
 		A80000000000000000000004 /* PBXTargetDependency */ = {isa = PBXTargetDependency; target = A20000000000000000000001 /* ReleaseRadar */; targetProxy = A70000000000000000000004 /* PBXContainerItemProxy */; };
+		A80000000000000000000005 /* PBXTargetDependency */ = {isa = PBXTargetDependency; target = A20000000000000000000006 /* ReleaseRadarBridgeAgent */; targetProxy = A70000000000000000000005 /* PBXContainerItemProxy */; };
+		A80000000000000000000006 /* PBXTargetDependency */ = {isa = PBXTargetDependency; target = A20000000000000000000003 /* ReleaseRadarAgentTools */; targetProxy = A70000000000000000000006 /* PBXContainerItemProxy */; };
+		A80000000000000000000007 /* PBXTargetDependency */ = {isa = PBXTargetDependency; target = A20000000000000000000007 /* ReleaseRadarWrongAgentTools */; targetProxy = A70000000000000000000007 /* PBXContainerItemProxy */; };
 /* End PBXTargetDependency section */
 
 /* Begin XCBuildConfiguration section */
 		A50000000000000000000050 /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {ALWAYS_SEARCH_USER_PATHS = NO; CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; CODE_SIGN_IDENTITY = "Apple Development: jaroberts4@gmail.com (PT7GS96H3L)"; CODE_SIGN_STYLE = Manual; DEBUG_INFORMATION_FORMAT = dwarf; DEVELOPMENT_TEAM = 2UA854NLX4; ENABLE_CODE_COVERAGE = NO; ENABLE_TESTABILITY = YES; GCC_OPTIMIZATION_LEVEL = 0; MACOSX_DEPLOYMENT_TARGET = 14.0; ONLY_ACTIVE_ARCH = YES; SDKROOT = macosx; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; SWIFT_OPTIMIZATION_LEVEL = "-Onone"; SWIFT_VERSION = 6.0; }; name = Debug; };
 		A50000000000000000000051 /* Release */ = {isa = XCBuildConfiguration; buildSettings = {ALWAYS_SEARCH_USER_PATHS = NO; CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; CODE_SIGN_IDENTITY = "Apple Development: jaroberts4@gmail.com (PT7GS96H3L)"; CODE_SIGN_STYLE = Manual; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"; DEVELOPMENT_TEAM = 2UA854NLX4; MACOSX_DEPLOYMENT_TARGET = 14.0; SDKROOT = macosx; SWIFT_COMPILATION_MODE = wholemodule; SWIFT_OPTIMIZATION_LEVEL = "-O"; SWIFT_VERSION = 6.0; }; name = Release; };
 		A50000000000000000000053 /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {CODE_SIGN_ENTITLEMENTS = ReleaseRadar/ReleaseRadar.entitlements; COMBINE_HIDPI_IMAGES = YES; CURRENT_PROJECT_VERSION = 1; ENABLE_HARDENED_RUNTIME = YES; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = ReleaseRadar/Info.plist; LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/../Frameworks", ); MARKETING_VERSION = 0.1.0; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadar; PRODUCT_NAME = ReleaseRadar; SWIFT_EMIT_LOC_STRINGS = YES; }; name = Debug; };
 		A50000000000000000000054 /* Release */ = {isa = XCBuildConfiguration; buildSettings = {CODE_SIGN_ENTITLEMENTS = ReleaseRadar/ReleaseRadar.entitlements; COMBINE_HIDPI_IMAGES = YES; CURRENT_PROJECT_VERSION = 1; ENABLE_HARDENED_RUNTIME = YES; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = ReleaseRadar/Info.plist; LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/../Frameworks", ); MARKETING_VERSION = 0.1.0; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadar; PRODUCT_NAME = ReleaseRadar; SWIFT_EMIT_LOC_STRINGS = YES; }; name = Release; };
 		A50000000000000000000056 /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {DEFINES_MODULE = YES; DYLIB_INSTALL_NAME_BASE = "@rpath"; ENABLE_HARDENED_RUNTIME = YES; GENERATE_INFOPLIST_FILE = YES; INSTALL_PATH = "$(LOCAL_LIBRARY_DIR)/Frameworks"; OTHER_LDFLAGS = "-lsqlite3"; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarCore; PRODUCT_NAME = ReleaseRadarCore; SKIP_INSTALL = YES; }; name = Debug; };
 		A50000000000000000000057 /* Release */ = {isa = XCBuildConfiguration; buildSettings = {DEFINES_MODULE = YES; DYLIB_INSTALL_NAME_BASE = "@rpath"; ENABLE_HARDENED_RUNTIME = YES; GENERATE_INFOPLIST_FILE = YES; INSTALL_PATH = "$(LOCAL_LIBRARY_DIR)/Frameworks"; OTHER_LDFLAGS = "-lsqlite3"; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarCore; PRODUCT_NAME = ReleaseRadarCore; SKIP_INSTALL = YES; }; name = Release; };
-		A50000000000000000000059 /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {ENABLE_HARDENED_RUNTIME = YES; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarAgentTools; PRODUCT_NAME = ReleaseRadarAgentTools; }; name = Debug; };
-		A5000000000000000000005A /* Release */ = {isa = XCBuildConfiguration; buildSettings = {ENABLE_HARDENED_RUNTIME = YES; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarAgentTools; PRODUCT_NAME = ReleaseRadarAgentTools; }; name = Release; };
+		A50000000000000000000059 /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO; CREATE_INFOPLIST_SECTION_IN_BINARY = YES; ENABLE_HARDENED_RUNTIME = YES; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarAgentTools; PRODUCT_NAME = ReleaseRadarAgentTools; }; name = Debug; };
+		A5000000000000000000005A /* Release */ = {isa = XCBuildConfiguration; buildSettings = {CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO; CREATE_INFOPLIST_SECTION_IN_BINARY = YES; ENABLE_HARDENED_RUNTIME = YES; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarAgentTools; PRODUCT_NAME = ReleaseRadarAgentTools; }; name = Release; };
 		A5000000000000000000005C /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {BUNDLE_LOADER = "$(TEST_HOST)"; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarTests; PRODUCT_NAME = ReleaseRadarTests; SKIP_INSTALL = YES; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/ReleaseRadar.app/Contents/MacOS/ReleaseRadar"; }; name = Debug; };
 		A5000000000000000000005D /* Release */ = {isa = XCBuildConfiguration; buildSettings = {BUNDLE_LOADER = "$(TEST_HOST)"; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarTests; PRODUCT_NAME = ReleaseRadarTests; SKIP_INSTALL = YES; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/ReleaseRadar.app/Contents/MacOS/ReleaseRadar"; }; name = Release; };
 		A5000000000000000000005F /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarUITests; PRODUCT_NAME = ReleaseRadarUITests; SKIP_INSTALL = YES; TEST_TARGET_NAME = ReleaseRadar; }; name = Debug; };
 		A50000000000000000000060 /* Release */ = {isa = XCBuildConfiguration; buildSettings = {GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarUITests; PRODUCT_NAME = ReleaseRadarUITests; SKIP_INSTALL = YES; TEST_TARGET_NAME = ReleaseRadar; }; name = Release; };
+		A50000000000000000000062 /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {CODE_SIGN_ENTITLEMENTS = ReleaseRadarBridgeAgent/ReleaseRadarBridgeAgent.entitlements; CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO; CREATE_INFOPLIST_SECTION_IN_BINARY = YES; ENABLE_HARDENED_RUNTIME = YES; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarBridgeAgent; PRODUCT_NAME = ReleaseRadarBridgeAgent; SKIP_INSTALL = YES; }; name = Debug; };
+		A50000000000000000000063 /* Release */ = {isa = XCBuildConfiguration; buildSettings = {CODE_SIGN_ENTITLEMENTS = ReleaseRadarBridgeAgent/ReleaseRadarBridgeAgent.entitlements; CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO; CREATE_INFOPLIST_SECTION_IN_BINARY = YES; ENABLE_HARDENED_RUNTIME = YES; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarBridgeAgent; PRODUCT_NAME = ReleaseRadarBridgeAgent; SKIP_INSTALL = YES; }; name = Release; };
+		A50000000000000000000065 /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO; CREATE_INFOPLIST_SECTION_IN_BINARY = YES; ENABLE_HARDENED_RUNTIME = YES; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarWrongAgentTools; PRODUCT_NAME = ReleaseRadarWrongAgentTools; SKIP_INSTALL = YES; }; name = Debug; };
+		A50000000000000000000066 /* Release */ = {isa = XCBuildConfiguration; buildSettings = {CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO; CREATE_INFOPLIST_SECTION_IN_BINARY = YES; ENABLE_HARDENED_RUNTIME = YES; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarWrongAgentTools; PRODUCT_NAME = ReleaseRadarWrongAgentTools; SKIP_INSTALL = YES; }; name = Release; };
 /* End XCBuildConfiguration section */
 
 /* Begin XCConfigurationList section */
 		A50000000000000000000052 /* Build configuration list for PBXProject "ReleaseRadar" */ = {isa = XCConfigurationList; buildConfigurations = (A50000000000000000000050 /* Debug */, A50000000000000000000051 /* Release */, ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
 		A50000000000000000000055 /* Build configuration list for PBXNativeTarget "ReleaseRadar" */ = {isa = XCConfigurationList; buildConfigurations = (A50000000000000000000053 /* Debug */, A50000000000000000000054 /* Release */, ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
 		A50000000000000000000058 /* Build configuration list for PBXNativeTarget "ReleaseRadarCore" */ = {isa = XCConfigurationList; buildConfigurations = (A50000000000000000000056 /* Debug */, A50000000000000000000057 /* Release */, ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
 		A5000000000000000000005B /* Build configuration list for PBXNativeTarget "ReleaseRadarAgentTools" */ = {isa = XCConfigurationList; buildConfigurations = (A50000000000000000000059 /* Debug */, A5000000000000000000005A /* Release */, ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
 		A5000000000000000000005E /* Build configuration list for PBXNativeTarget "ReleaseRadarTests" */ = {isa = XCConfigurationList; buildConfigurations = (A5000000000000000000005C /* Debug */, A5000000000000000000005D /* Release */, ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
 		A50000000000000000000061 /* Build configuration list for PBXNativeTarget "ReleaseRadarUITests" */ = {isa = XCConfigurationList; buildConfigurations = (A5000000000000000000005F /* Debug */, A50000000000000000000060 /* Release */, ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
+		A50000000000000000000064 /* Build configuration list for PBXNativeTarget "ReleaseRadarBridgeAgent" */ = {isa = XCConfigurationList; buildConfigurations = (A50000000000000000000062 /* Debug */, A50000000000000000000063 /* Release */, ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
+		A50000000000000000000067 /* Build configuration list for PBXNativeTarget "ReleaseRadarWrongAgentTools" */ = {isa = XCConfigurationList; buildConfigurations = (A50000000000000000000065 /* Debug */, A50000000000000000000066 /* Release */, ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
 /* End XCConfigurationList section */
 	};
 	rootObject = A30000000000000000000001 /* Project object */;
 }
diff --git a/ReleaseRadar/App/ReleaseRadarApp.swift b/ReleaseRadar/App/ReleaseRadarApp.swift
index 65b223d..37856f3 100644
--- a/ReleaseRadar/App/ReleaseRadarApp.swift
+++ b/ReleaseRadar/App/ReleaseRadarApp.swift
@@ -1,17 +1,49 @@
 import AppKit
+import OSLog
+import ReleaseRadarCore
 import SwiftUI
 
+@MainActor
 final class AppDelegate: NSObject, NSApplicationDelegate {
+    private let logger = Logger(subsystem: "com.rekonlabs.ReleaseRadar", category: "AgentBridge")
+    private var agentBridgeHost: AgentBridgeApplicationHost?
+
     func applicationDidFinishLaunching(_ notification: Notification) {
         NSApp.setActivationPolicy(.regular)
         NSApp.activate(ignoringOtherApps: true)
+        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
+            return
+        }
+        Task { [weak self] in
+            do {
+                _ = try await self?.startAgentBridge()
+            } catch {
+                self?.logger.error("Agent bridge startup failed: \(error.localizedDescription)")
+            }
+        }
+    }
+
+    func applicationWillTerminate(_ notification: Notification) {
+        agentBridgeHost?.disconnectCallback()
+        agentBridgeHost = nil
+    }
+
+    func startAgentBridge(
+        databaseURL: URL = DeliveryStore.applicationSupportDatabaseURL()
+    ) async throws -> AgentBridgeApplicationHost {
+        if let agentBridgeHost {
+            return agentBridgeHost
+        }
+        let host = try await AgentBridgeApplicationHost.start(databaseURL: databaseURL)
+        agentBridgeHost = host
+        return host
     }
 }
 
 @main
 struct ReleaseRadarApp: App {
     @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
     @State private var model = AppModel()
 
     var body: some Scene {
         WindowGroup("Release Radar", id: "main") {
diff --git a/ReleaseRadar/ReleaseRadar.entitlements b/ReleaseRadar/ReleaseRadar.entitlements
index 13cb114..1e5cd69 100644
--- a/ReleaseRadar/ReleaseRadar.entitlements
+++ b/ReleaseRadar/ReleaseRadar.entitlements
@@ -1,8 +1,12 @@
 <?xml version="1.0" encoding="UTF-8"?>
 <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
 <plist version="1.0">
 <dict>
     <key>com.apple.security.app-sandbox</key>
     <true/>
+    <key>com.apple.security.application-groups</key>
+    <array>
+        <string>2UA854NLX4.com.rekonlabs.ReleaseRadar</string>
+    </array>
 </dict>
 </plist>
diff --git a/ReleaseRadarAgentTools/main.swift b/ReleaseRadarAgentTools/main.swift
index a3b6b4e..bafaa3e 100644
--- a/ReleaseRadarAgentTools/main.swift
+++ b/ReleaseRadarAgentTools/main.swift
@@ -1,3 +1,385 @@
 import Foundation
 
-FileHandle.standardOutput.write(Data("ReleaseRadarAgentTools foundation\n".utf8))
+private enum ToolFailure: Error, LocalizedError {
+    case invalidRequest(String)
+    case bridgeUnavailable
+
+    var errorDescription: String? {
+        switch self {
+        case let .invalidRequest(message): message
+        case .bridgeUnavailable: "Release Radar app is unavailable"
+        }
+    }
+}
+
+private final class BridgeClient: @unchecked Sendable {
+    private let connection: NSXPCConnection
+    private let requestedVersion: Int
+
+    init() throws {
+        guard let brokerRequirement = ReleaseRadarBridgeTransport.brokerRequirement else {
+            throw ToolFailure.bridgeUnavailable
+        }
+#if DEBUG
+        requestedVersion = ProcessInfo.processInfo.environment["RELEASE_RADAR_BRIDGE_VERSION"]
+            .flatMap(Int.init) ?? ReleaseRadarBridgeTransport.version
+#else
+        requestedVersion = ReleaseRadarBridgeTransport.version
+#endif
+        connection = NSXPCConnection(
+            machServiceName: ReleaseRadarBridgeTransport.toolsMachService,
+            options: []
+        )
+        connection.remoteObjectInterface = NSXPCInterface(with: ReleaseRadarToolsBrokerXPC.self)
+        connection.setCodeSigningRequirement(brokerRequirement)
+        connection.resume()
+        guard handshake() else {
+            connection.invalidate()
+            throw ToolFailure.bridgeUnavailable
+        }
+    }
+
+    deinit {
+        connection.invalidate()
+    }
+
+    func forward(_ envelope: Data) throws -> Data {
+        let semaphore = DispatchSemaphore(value: 0)
+        let lock = NSLock()
+        var response: Data?
+        var failed = false
+        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in
+            lock.lock()
+            failed = true
+            lock.unlock()
+            semaphore.signal()
+        }) as? ReleaseRadarToolsBrokerXPC else {
+            throw ToolFailure.bridgeUnavailable
+        }
+        proxy.forward(
+            requestedVersion,
+            envelope: envelope,
+            deadline: Date().addingTimeInterval(10).timeIntervalSince1970
+        ) { data in
+            lock.lock()
+            response = data
+            lock.unlock()
+            semaphore.signal()
+        }
+        guard semaphore.wait(timeout: .now() + 12) == .success else {
+            throw ToolFailure.bridgeUnavailable
+        }
+        lock.lock()
+        defer { lock.unlock() }
+        guard !failed, let response else { throw ToolFailure.bridgeUnavailable }
+        return response
+    }
+
+    private func handshake() -> Bool {
+        let semaphore = DispatchSemaphore(value: 0)
+        let lock = NSLock()
+        var returnedVersion = 0
+        var failed = false
+        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in
+            lock.lock()
+            failed = true
+            lock.unlock()
+            semaphore.signal()
+        }) as? ReleaseRadarToolsBrokerXPC else { return false }
+        proxy.handshake(requestedVersion) { version in
+            lock.lock()
+            returnedVersion = version
+            lock.unlock()
+            semaphore.signal()
+        }
+        guard semaphore.wait(timeout: .now() + 5) == .success else { return false }
+        lock.lock()
+        defer { lock.unlock() }
+        return !failed && returnedVersion == requestedVersion
+    }
+}
+
+private struct MCPServer {
+    private var initialized = false
+
+    mutating func handle(_ request: [String: Any]) -> [String: Any]? {
+        let id = request["id"] ?? NSNull()
+        guard request["jsonrpc"] as? String == "2.0",
+              let method = request["method"] as? String
+        else { return error(id: id, code: -32600, message: "Invalid JSON-RPC request") }
+
+        switch method {
+        case "initialize":
+            initialized = true
+            return success(id: id, result: [
+                "protocolVersion": "2025-06-18",
+                "capabilities": ["tools": [:]],
+                "serverInfo": ["name": "Release Radar", "version": "1"],
+            ])
+        case "notifications/initialized":
+            return nil
+        case "tools/list":
+            guard initialized else { return error(id: id, code: -32002, message: "MCP session is not initialized") }
+            return success(id: id, result: ["tools": Self.toolDefinitions])
+        case "tools/call":
+            guard initialized else { return error(id: id, code: -32002, message: "MCP session is not initialized") }
+            guard let params = request["params"] as? [String: Any],
+                  let name = params["name"] as? String,
+                  let arguments = params["arguments"] as? [String: Any]
+            else { return error(id: id, code: -32602, message: "Invalid tool arguments") }
+            do {
+                let envelope = try Self.makeEnvelope(tool: name, arguments: arguments)
+                let response = try BridgeClient().forward(envelope)
+                return success(id: id, result: [
+                    "content": [["type": "text", "text": String(decoding: response, as: UTF8.self)]],
+                    "isError": false,
+                ])
+            } catch ToolFailure.bridgeUnavailable {
+                return error(id: id, code: -32001, message: "Release Radar app is unavailable")
+            } catch {
+                return self.error(id: id, code: -32602, message: error.localizedDescription)
+            }
+        default:
+            return error(id: id, code: -32601, message: "Method not found")
+        }
+    }
+
+    private static func makeEnvelope(tool: String, arguments: [String: Any]) throws -> Data {
+        let version = try integer("version", in: arguments)
+        let requestID = try string("requestID", in: arguments)
+        guard UUID(uuidString: requestID) != nil else {
+            throw ToolFailure.invalidRequest("requestID must be a UUID")
+        }
+        let command = try commandCase(tool: tool, arguments: arguments)
+        var envelope: [String: Any] = [
+            "version": version,
+            "requestID": requestID,
+            "projectRoot": try string("projectRoot", in: arguments),
+            "reason": try string("reason", in: arguments),
+            "command": [command.0: command.1],
+        ]
+        if let threadID = arguments["assertedThreadID"] as? String {
+            envelope["assertedThreadID"] = threadID
+        }
+        let data = try JSONSerialization.data(withJSONObject: envelope)
+        guard data.count <= ReleaseRadarBridgeTransport.maximumEnvelopeBytes else {
+            throw ToolFailure.invalidRequest("Command envelope exceeds the transport limit")
+        }
+        return data
+    }
+
+    private static func commandCase(
+        tool: String,
+        arguments: [String: Any]
+    ) throws -> (String, [String: Any]) {
+        switch tool {
+        case "release_radar_upsert_phase":
+            return ("upsertPhase", ["phaseID": try string("phaseID", in: arguments), "name": try string("name", in: arguments)])
+        case "release_radar_upsert_ticket":
+            return ("upsertTicket", [
+                "ticketID": try string("ticketID", in: arguments),
+                "phaseID": try string("phaseID", in: arguments),
+                "outcome": try string("outcome", in: arguments),
+                "lane": try string("lane", in: arguments),
+            ])
+        case "release_radar_transition_ticket":
+            return ("transitionTicket", [
+                "ticketID": try string("ticketID", in: arguments),
+                "lane": try string("lane", in: arguments),
+            ])
+        case "release_radar_set_dependency":
+            return ("setDependency", [
+                "id": try string("id", in: arguments),
+                "kind": try string("kind", in: arguments),
+                "subjectID": try string("subjectID", in: arguments),
+                "dependsOnID": try string("dependsOnID", in: arguments),
+            ])
+        case "release_radar_record_blocker":
+            return ("recordBlocker", [
+                "id": try string("id", in: arguments),
+                "ticketID": try string("ticketID", in: arguments),
+                "summary": try string("summary", in: arguments),
+            ])
+        case "release_radar_resolve_blocker":
+            return ("resolveBlocker", ["blockerID": try string("blockerID", in: arguments)])
+        case "release_radar_add_evidence":
+            var value: [String: Any] = [
+                "id": try string("id", in: arguments),
+                "path": try string("path", in: arguments),
+            ]
+            if let ticketID = arguments["ticketID"] as? String { value["ticketID"] = ticketID }
+            return ("addEvidence", value)
+        case "release_radar_link_thread":
+            return ("linkThread", [
+                "id": try string("id", in: arguments),
+                "ticketID": try string("ticketID", in: arguments),
+                "threadID": try string("threadID", in: arguments),
+            ])
+        case "release_radar_request_review":
+            var value: [String: Any] = [
+                "id": try string("id", in: arguments),
+                "kind": try string("kind", in: arguments),
+                "summary": try string("summary", in: arguments),
+            ]
+            if let ticketID = arguments["ticketID"] as? String { value["ticketID"] = ticketID }
+            return ("requestReview", value)
+        case "release_radar_record_completion":
+            return ("recordCompletion", [
+                "id": try string("id", in: arguments),
+                "ticketID": try string("ticketID", in: arguments),
+                "summary": try string("summary", in: arguments),
+            ])
+        case "release_radar_resolve_import_review":
+            return ("resolveImportReview", ["reviewItemID": try string("reviewItemID", in: arguments)])
+        case "release_radar_dismiss_import_review":
+            return ("dismissImportReview", ["reviewItemID": try string("reviewItemID", in: arguments)])
+        default:
+            throw ToolFailure.invalidRequest("Unknown Release Radar tool")
+        }
+    }
+
+    private static func string(_ key: String, in arguments: [String: Any]) throws -> String {
+        guard let value = arguments[key] as? String else {
+            throw ToolFailure.invalidRequest("Missing string argument: \(key)")
+        }
+        return value
+    }
+
+    private static func integer(_ key: String, in arguments: [String: Any]) throws -> Int {
+        guard let value = arguments[key] as? NSNumber else {
+            throw ToolFailure.invalidRequest("Missing integer argument: \(key)")
+        }
+        return value.intValue
+    }
+
+    private func success(id: Any, result: Any) -> [String: Any] {
+        ["jsonrpc": "2.0", "id": id, "result": result]
+    }
+
+    private func error(id: Any, code: Int, message: String) -> [String: Any] {
+        ["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]]
+    }
+
+    private static var toolDefinitions: [[String: Any]] {
+        let string: [String: Any] = ["type": "string", "minLength": 1]
+        let lane: [String: Any] = [
+            "type": "string",
+            "enum": ["backlog", "in_progress", "needs_review", "blocked", "accepted"],
+        ]
+        return [
+            definition("release_radar_upsert_phase", required: ["phaseID", "name"], fields: ["phaseID": string, "name": string]),
+            definition(
+                "release_radar_upsert_ticket",
+                required: ["ticketID", "phaseID", "outcome", "lane"],
+                fields: ["ticketID": string, "phaseID": string, "outcome": string, "lane": lane]
+            ),
+            definition(
+                "release_radar_transition_ticket",
+                required: ["ticketID", "lane"],
+                fields: ["ticketID": string, "lane": lane]
+            ),
+            definition(
+                "release_radar_set_dependency",
+                required: ["id", "kind", "subjectID", "dependsOnID"],
+                fields: [
+                    "id": string,
+                    "kind": ["type": "string", "enum": ["phase", "ticket"]],
+                    "subjectID": string,
+                    "dependsOnID": string,
+                ]
+            ),
+            definition(
+                "release_radar_record_blocker",
+                required: ["id", "ticketID", "summary"],
+                fields: ["id": string, "ticketID": string, "summary": string]
+            ),
+            definition("release_radar_resolve_blocker", required: ["blockerID"], fields: ["blockerID": string]),
+            definition(
+                "release_radar_add_evidence",
+                required: ["id", "path"],
+                fields: ["id": string, "ticketID": string, "path": string]
+            ),
+            definition(
+                "release_radar_link_thread",
+                required: ["id", "ticketID", "threadID"],
+                fields: ["id": string, "ticketID": string, "threadID": string]
+            ),
+            definition(
+                "release_radar_request_review",
+                required: ["id", "kind", "summary"],
+                fields: ["id": string, "ticketID": string, "kind": string, "summary": string]
+            ),
+            definition(
+                "release_radar_record_completion",
+                required: ["id", "ticketID", "summary"],
+                fields: ["id": string, "ticketID": string, "summary": string]
+            ),
+            definition(
+                "release_radar_resolve_import_review",
+                required: ["reviewItemID"],
+                fields: ["reviewItemID": string]
+            ),
+            definition(
+                "release_radar_dismiss_import_review",
+                required: ["reviewItemID"],
+                fields: ["reviewItemID": string]
+            ),
+        ]
+    }
+
+    private static func definition(
+        _ name: String,
+        required: [String],
+        fields: [String: [String: Any]]
+    ) -> [String: Any] {
+        var properties: [String: Any] = [
+            "version": ["type": "integer", "const": ReleaseRadarBridgeTransport.version],
+            "requestID": ["type": "string", "format": "uuid"],
+            "projectRoot": ["type": "string", "minLength": 1],
+            "assertedThreadID": ["type": "string", "minLength": 1],
+            "reason": ["type": "string", "minLength": 1],
+        ]
+        properties.merge(fields) { _, commandField in commandField }
+        return [
+            "name": name,
+            "description": "Apply one approved, audited Release Radar delivery mutation.",
+            "inputSchema": [
+                "type": "object",
+                "properties": properties,
+                "required": ["version", "requestID", "projectRoot", "reason"] + required,
+                "additionalProperties": false,
+            ],
+        ]
+    }
+}
+
+private func writeResponse(_ response: [String: Any]) {
+    guard let data = try? JSONSerialization.data(withJSONObject: response) else { return }
+    FileHandle.standardOutput.write(data)
+    FileHandle.standardOutput.write(Data([0x0A]))
+}
+
+private var server = MCPServer()
+private var buffer = Data()
+while let chunk = try? FileHandle.standardInput.read(upToCount: 4_096), !chunk.isEmpty {
+    buffer.append(chunk)
+    if buffer.count > ReleaseRadarBridgeTransport.maximumLineBytes,
+       !buffer.contains(0x0A) {
+        writeResponse(["jsonrpc": "2.0", "id": NSNull(), "error": ["code": -32600, "message": "JSON-RPC line exceeds limit"]])
+        exit(64)
+    }
+    while let newline = buffer.firstIndex(of: 0x0A) {
+        let line = Data(buffer[..<newline])
+        buffer.removeSubrange(...newline)
+        guard !line.isEmpty else { continue }
+        guard line.count <= ReleaseRadarBridgeTransport.maximumLineBytes,
+              let request = try? JSONSerialization.jsonObject(with: line) as? [String: Any]
+        else {
+            writeResponse(["jsonrpc": "2.0", "id": NSNull(), "error": ["code": -32700, "message": "Invalid bounded JSON"]])
+            continue
+        }
+        if let response = server.handle(request) {
+            writeResponse(response)
+        }
+    }
+}
diff --git a/ReleaseRadarBridgeAgent/ReleaseRadarBridgeAgent.entitlements b/ReleaseRadarBridgeAgent/ReleaseRadarBridgeAgent.entitlements
new file mode 100644
index 0000000..1e5cd69
--- /dev/null
+++ b/ReleaseRadarBridgeAgent/ReleaseRadarBridgeAgent.entitlements
@@ -0,0 +1,12 @@
+<?xml version="1.0" encoding="UTF-8"?>
+<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
+<plist version="1.0">
+<dict>
+    <key>com.apple.security.app-sandbox</key>
+    <true/>
+    <key>com.apple.security.application-groups</key>
+    <array>
+        <string>2UA854NLX4.com.rekonlabs.ReleaseRadar</string>
+    </array>
+</dict>
+</plist>
diff --git a/ReleaseRadarBridgeAgent/com.rekonlabs.ReleaseRadar.BridgeAgent.plist b/ReleaseRadarBridgeAgent/com.rekonlabs.ReleaseRadar.BridgeAgent.plist
new file mode 100644
index 0000000..c5cd789
--- /dev/null
+++ b/ReleaseRadarBridgeAgent/com.rekonlabs.ReleaseRadar.BridgeAgent.plist
@@ -0,0 +1,17 @@
+<?xml version="1.0" encoding="UTF-8"?>
+<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
+<plist version="1.0">
+<dict>
+    <key>Label</key>
+    <string>com.rekonlabs.ReleaseRadar.BridgeAgent</string>
+    <key>BundleProgram</key>
+    <string>Contents/Resources/ReleaseRadarBridgeAgent</string>
+    <key>MachServices</key>
+    <dict>
+        <key>2UA854NLX4.com.rekonlabs.ReleaseRadar.bridge.app</key>
+        <true/>
+        <key>2UA854NLX4.com.rekonlabs.ReleaseRadar.bridge.tools</key>
+        <true/>
+    </dict>
+</dict>
+</plist>
diff --git a/ReleaseRadarBridgeAgent/main.swift b/ReleaseRadarBridgeAgent/main.swift
new file mode 100644
index 0000000..1666e94
--- /dev/null
+++ b/ReleaseRadarBridgeAgent/main.swift
@@ -0,0 +1,179 @@
+import Darwin
+import Foundation
+
+private final class BridgeBrokerState: @unchecked Sendable {
+    private let lock = NSLock()
+    private var appConnection: NSXPCConnection?
+
+    func registerApp(_ connection: NSXPCConnection) {
+        lock.lock()
+        appConnection = connection
+        lock.unlock()
+    }
+
+    func removeApp(_ connection: NSXPCConnection) {
+        lock.lock()
+        if appConnection === connection {
+            appConnection = nil
+        }
+        lock.unlock()
+    }
+
+    func forward(
+        version: Int,
+        envelope: Data,
+        deadline: TimeInterval,
+        reply: @escaping (Data) -> Void
+    ) {
+        guard version == ReleaseRadarBridgeTransport.version,
+              envelope.count <= ReleaseRadarBridgeTransport.maximumEnvelopeBytes,
+              deadline > Date().timeIntervalSince1970,
+              deadline - Date().timeIntervalSince1970 <= ReleaseRadarBridgeTransport.maximumDeadlineInterval
+        else {
+            reply(ReleaseRadarBridgeTransport.appUnavailableResultData())
+            return
+        }
+        guard let envelopeVersion = ReleaseRadarBridgeTransport.envelopeVersion(in: envelope) else {
+            reply(ReleaseRadarBridgeTransport.appUnavailableResultData())
+            return
+        }
+        guard envelopeVersion == ReleaseRadarBridgeTransport.version else {
+            reply(ReleaseRadarBridgeTransport.unsupportedVersionResultData(found: envelopeVersion))
+            return
+        }
+
+        lock.lock()
+        let connection = appConnection
+        lock.unlock()
+        guard let connection else {
+            reply(ReleaseRadarBridgeTransport.appUnavailableResultData())
+            return
+        }
+
+        let once = BridgeReplyOnce(reply)
+        let delay = max(0, deadline - Date().timeIntervalSince1970)
+        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
+            once.send(ReleaseRadarBridgeTransport.appUnavailableResultData())
+        }
+        guard let callback = connection.remoteObjectProxyWithErrorHandler({ _ in
+            once.send(ReleaseRadarBridgeTransport.appUnavailableResultData())
+        }) as? ReleaseRadarAppCallbackXPC else {
+            once.send(ReleaseRadarBridgeTransport.appUnavailableResultData())
+            return
+        }
+        callback.dispatch(version, envelope: envelope, deadline: deadline) { data in
+            once.send(data)
+        }
+    }
+}
+
+private final class ToolsEndpoint: NSObject, ReleaseRadarToolsBrokerXPC, @unchecked Sendable {
+    private let state: BridgeBrokerState
+
+    init(state: BridgeBrokerState) {
+        self.state = state
+    }
+
+    func handshake(_ version: Int, withReply reply: @escaping (Int) -> Void) {
+        reply(version == ReleaseRadarBridgeTransport.version ? ReleaseRadarBridgeTransport.version : 0)
+    }
+
+    func forward(
+        _ version: Int,
+        envelope: Data,
+        deadline: TimeInterval,
+        withReply reply: @escaping (Data) -> Void
+    ) {
+        state.forward(version: version, envelope: envelope, deadline: deadline, reply: reply)
+    }
+}
+
+private final class AppEndpoint: NSObject, ReleaseRadarAppBrokerXPC, @unchecked Sendable {
+    private let state: BridgeBrokerState
+    private let connection: NSXPCConnection
+
+    init(state: BridgeBrokerState, connection: NSXPCConnection) {
+        self.state = state
+        self.connection = connection
+    }
+
+    func registerApp(_ version: Int, withReply reply: @escaping (Int) -> Void) {
+        guard version == ReleaseRadarBridgeTransport.version else {
+            reply(0)
+            return
+        }
+        state.registerApp(connection)
+        reply(ReleaseRadarBridgeTransport.version)
+    }
+}
+
+private final class ToolsListenerDelegate: NSObject, NSXPCListenerDelegate {
+    private let state: BridgeBrokerState
+
+    init(state: BridgeBrokerState) {
+        self.state = state
+    }
+
+    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
+        guard connection.effectiveUserIdentifier == getuid(),
+              let requirement = ReleaseRadarBridgeTransport.toolsRequirement
+        else { return false }
+        connection.setCodeSigningRequirement(requirement)
+        connection.exportedInterface = NSXPCInterface(with: ReleaseRadarToolsBrokerXPC.self)
+        connection.exportedObject = ToolsEndpoint(state: state)
+        connection.resume()
+        return true
+    }
+}
+
+private final class AppListenerDelegate: NSObject, NSXPCListenerDelegate {
+    private let state: BridgeBrokerState
+
+    init(state: BridgeBrokerState) {
+        self.state = state
+    }
+
+    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
+        guard connection.effectiveUserIdentifier == getuid(),
+              let requirement = ReleaseRadarBridgeTransport.appRequirement
+        else { return false }
+        connection.setCodeSigningRequirement(requirement)
+        connection.remoteObjectInterface = NSXPCInterface(with: ReleaseRadarAppCallbackXPC.self)
+        connection.exportedInterface = NSXPCInterface(with: ReleaseRadarAppBrokerXPC.self)
+        connection.exportedObject = AppEndpoint(state: state, connection: connection)
+        connection.invalidationHandler = { [state, weak connection] in
+            guard let connection else { return }
+            state.removeApp(connection)
+        }
+        connection.resume()
+        return true
+    }
+}
+
+private final class BridgeReplyOnce: @unchecked Sendable {
+    private let lock = NSLock()
+    private var reply: ((Data) -> Void)?
+
+    init(_ reply: @escaping (Data) -> Void) {
+        self.reply = reply
+    }
+
+    func send(_ data: Data) {
+        lock.lock()
+        let callback = reply
+        reply = nil
+        lock.unlock()
+        callback?(data)
+    }
+}
+
+private let brokerState = BridgeBrokerState()
+private let toolsDelegate = ToolsListenerDelegate(state: brokerState)
+private let appDelegate = AppListenerDelegate(state: brokerState)
+private let toolsListener = NSXPCListener(machServiceName: ReleaseRadarBridgeTransport.toolsMachService)
+private let appListener = NSXPCListener(machServiceName: ReleaseRadarBridgeTransport.appMachService)
+toolsListener.delegate = toolsDelegate
+appListener.delegate = appDelegate
+toolsListener.resume()
+appListener.resume()
+RunLoop.current.run()
diff --git a/ReleaseRadarCore/AgentBridge/AgentCommand.swift b/ReleaseRadarCore/AgentBridge/AgentCommand.swift
new file mode 100644
index 0000000..b0407d3
--- /dev/null
+++ b/ReleaseRadarCore/AgentBridge/AgentCommand.swift
@@ -0,0 +1,105 @@
+import Foundation
+
+public struct AgentCommandEnvelope: Codable, Equatable, Sendable {
+    public let version: Int
+    public let requestID: UUID
+    public let projectRoot: String
+    public let assertedThreadID: String?
+    public let reason: String
+    public let command: AgentCommand
+
+    public init(
+        version: Int,
+        requestID: UUID,
+        projectRoot: String,
+        assertedThreadID: String? = nil,
+        reason: String,
+        command: AgentCommand
+    ) {
+        self.version = version
+        self.requestID = requestID
+        self.projectRoot = projectRoot
+        self.assertedThreadID = assertedThreadID
+        self.reason = reason
+        self.command = command
+    }
+}
+
+public enum AgentCommand: Codable, Equatable, Sendable {
+    case upsertPhase(phaseID: String, name: String)
+    case upsertTicket(ticketID: String, phaseID: String, outcome: String, lane: TicketLane)
+    case transitionTicket(ticketID: String, lane: TicketLane)
+    case setDependency(id: String, kind: DependencyKind, subjectID: String, dependsOnID: String)
+    case recordBlocker(id: String, ticketID: String, summary: String)
+    case resolveBlocker(blockerID: String)
+    case addEvidence(id: String, ticketID: String?, path: String)
+    case linkThread(id: String, ticketID: String, threadID: String)
+    case requestReview(id: String, ticketID: String?, kind: String, summary: String)
+    case recordCompletion(id: String, ticketID: String, summary: String)
+    case resolveImportReview(reviewItemID: String)
+    case dismissImportReview(reviewItemID: String)
+}
+
+public enum DependencyKind: String, Codable, Equatable, Sendable {
+    case phase
+    case ticket
+}
+
+public enum AgentCommandError: Codable, Equatable, Sendable {
+    case unsupportedVersion(found: Int, supported: Int)
+    case invalidEnvelope(String)
+    case unauthorizedProjectRoot
+    case invalidReference(String)
+    case crossProjectReference(String)
+    case dependencyCycle(String)
+    case requestIDReused
+    case appUnavailable
+    case internalFailure(String)
+}
+
+public struct AgentCommandResult: Codable, Equatable, Sendable {
+    public let entityIDs: [String]
+    public let auditEventID: AuditEventID?
+    public let error: AgentCommandError?
+
+    public init(entityIDs: [String], auditEventID: AuditEventID?, error: AgentCommandError?) {
+        self.entityIDs = entityIDs
+        self.auditEventID = auditEventID
+        self.error = error
+    }
+}
+
+public struct AuthorizedProject: Equatable, Sendable {
+    public let projectID: ProjectID
+    public let canonicalRoot: URL
+    public let authorizedRoots: [URL]
+
+    public init(projectID: ProjectID, canonicalRoot: URL, authorizedRoots: [URL]) {
+        self.projectID = projectID
+        self.canonicalRoot = Self.canonicalize(canonicalRoot)
+        self.authorizedRoots = authorizedRoots.map(Self.canonicalize)
+    }
+
+    static func canonicalize(_ url: URL) -> URL {
+        url.standardizedFileURL.resolvingSymlinksInPath()
+    }
+}
+
+public protocol AuthorizedProjectRegistry: Sendable {
+    func resolve(projectRoot: String) -> AuthorizedProject?
+}
+
+public struct InMemoryAuthorizedProjectRegistry: AuthorizedProjectRegistry, Sendable {
+    private let projects: [AuthorizedProject]
+
+    public init(projects: [AuthorizedProject]) {
+        self.projects = projects
+    }
+
+    public func resolve(projectRoot: String) -> AuthorizedProject? {
+        let supplied = AuthorizedProject.canonicalize(URL(fileURLWithPath: projectRoot))
+        return projects.first { project in
+            project.authorizedRoots.contains(supplied)
+        }
+    }
+}
diff --git a/ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift b/ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift
new file mode 100644
index 0000000..c2c6611
--- /dev/null
+++ b/ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift
@@ -0,0 +1,377 @@
+import Foundation
+
+public actor AgentCommandDispatcher {
+    public static let supportedVersion = 1
+
+    private let store: DeliveryStore
+    private let projectRegistry: any AuthorizedProjectRegistry
+
+    public init(store: DeliveryStore, projectRegistry: any AuthorizedProjectRegistry) {
+        self.store = store
+        self.projectRegistry = projectRegistry
+    }
+
+    public func dispatch(_ envelope: AgentCommandEnvelope) async -> AgentCommandResult {
+        if let error = validate(envelope) {
+            return .init(entityIDs: [], auditEventID: nil, error: error)
+        }
+        guard let project = projectRegistry.resolve(projectRoot: envelope.projectRoot) else {
+            return .init(entityIDs: [], auditEventID: nil, error: .unauthorizedProjectRoot)
+        }
+
+        do {
+            let requestBody = try canonicalRequestBody(envelope)
+            let auditEventID = AuditEventID(rawValue: UUID().uuidString)
+            let result = resultForCommand(envelope.command, auditEventID: auditEventID)
+            let resultData = try JSONEncoder().encode(result)
+            do {
+                return try await store.transact(
+                    actor: .init(
+                        id: "release-radar-agent",
+                        threadID: envelope.assertedThreadID,
+                        threadAttribution: envelope.assertedThreadID == nil
+                            ? ThreadAttribution.none
+                            : ThreadAttribution.asserted
+                    ),
+                    reason: envelope.reason,
+                    auditEventID: auditEventID
+                ) { connection in
+                    if let prior = try connection.row(
+                        "SELECT request_body, result_data FROM agent_command_requests WHERE request_id = ?",
+                        bindings: [.text(envelope.requestID.uuidString)]
+                    ) {
+                        guard prior["request_body"] == .blob(requestBody),
+                              case let .blob(priorResultData)? = prior["result_data"],
+                              let priorResult = try? JSONDecoder().decode(AgentCommandResult.self, from: priorResultData)
+                        else {
+                            throw DispatchControl.requestIDReused
+                        }
+                        throw DispatchControl.replay(priorResult)
+                    }
+
+                    try Self.apply(envelope.command, project: project, connection: connection)
+                    try connection.execute(
+                        "INSERT INTO agent_command_requests (request_id, request_body, result_data, created_at) VALUES (?, ?, ?, ?)",
+                        bindings: [
+                            .text(envelope.requestID.uuidString),
+                            .blob(requestBody),
+                            .blob(resultData),
+                            .text(ISO8601DateFormatter().string(from: Date())),
+                        ]
+                    )
+                    return result
+                }
+            } catch let control as DispatchControl {
+                switch control {
+                case let .replay(result): return result
+                case .requestIDReused:
+                    return .init(entityIDs: [], auditEventID: nil, error: .requestIDReused)
+                }
+            }
+        } catch let error as StoreError {
+            if case .unavailable = error {
+                return .init(entityIDs: [], auditEventID: nil, error: .appUnavailable)
+            }
+            return .init(entityIDs: [], auditEventID: nil, error: .internalFailure(error.localizedDescription))
+        } catch {
+            return .init(entityIDs: [], auditEventID: nil, error: Self.map(error))
+        }
+    }
+
+    private func validate(_ envelope: AgentCommandEnvelope) -> AgentCommandError? {
+        guard envelope.version == Self.supportedVersion else {
+            return .unsupportedVersion(found: envelope.version, supported: Self.supportedVersion)
+        }
+        guard !envelope.projectRoot.isEmpty, envelope.projectRoot.utf8.count <= 4_096 else {
+            return .invalidEnvelope("projectRoot must contain 1...4096 UTF-8 bytes")
+        }
+        guard !envelope.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
+              envelope.reason.utf8.count <= 1_000 else {
+            return .invalidEnvelope("reason must contain 1...1000 UTF-8 bytes")
+        }
+        if let threadID = envelope.assertedThreadID,
+           threadID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || threadID.utf8.count > 1_024 {
+            return .invalidEnvelope("assertedThreadID must contain 1...1024 UTF-8 bytes when present")
+        }
+        guard let data = try? JSONEncoder().encode(envelope.command), data.count <= 65_536 else {
+            return .invalidEnvelope("command payload must not exceed 65536 bytes")
+        }
+        func valid(_ value: String, maximum: Int = 4_096) -> Bool {
+            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
+                && value.utf8.count <= maximum
+        }
+        let commandFieldsAreValid: Bool
+        switch envelope.command {
+        case let .upsertPhase(phaseID, name):
+            commandFieldsAreValid = valid(phaseID, maximum: 256) && valid(name)
+        case let .upsertTicket(ticketID, phaseID, outcome, _):
+            commandFieldsAreValid = valid(ticketID, maximum: 256) && valid(phaseID, maximum: 256) && valid(outcome)
+        case let .transitionTicket(ticketID, _):
+            commandFieldsAreValid = valid(ticketID, maximum: 256)
+        case let .setDependency(id, _, subjectID, dependsOnID):
+            commandFieldsAreValid = valid(id, maximum: 256)
+                && valid(subjectID, maximum: 256)
+                && valid(dependsOnID, maximum: 256)
+        case let .recordBlocker(id, ticketID, summary):
+            commandFieldsAreValid = valid(id, maximum: 256) && valid(ticketID, maximum: 256) && valid(summary)
+        case let .resolveBlocker(blockerID):
+            commandFieldsAreValid = valid(blockerID, maximum: 256)
+        case let .addEvidence(id, ticketID, path):
+            commandFieldsAreValid = valid(id, maximum: 256)
+                && ticketID.map { valid($0, maximum: 256) } != false
+                && valid(path)
+        case let .linkThread(id, ticketID, threadID):
+            commandFieldsAreValid = valid(id, maximum: 256)
+                && valid(ticketID, maximum: 256)
+                && valid(threadID, maximum: 1_024)
+        case let .requestReview(id, ticketID, kind, summary):
+            commandFieldsAreValid = valid(id, maximum: 256)
+                && ticketID.map { valid($0, maximum: 256) } != false
+                && valid(kind, maximum: 256)
+                && valid(summary)
+        case let .recordCompletion(id, ticketID, summary):
+            commandFieldsAreValid = valid(id, maximum: 256) && valid(ticketID, maximum: 256) && valid(summary)
+        case let .resolveImportReview(reviewItemID), let .dismissImportReview(reviewItemID):
+            commandFieldsAreValid = valid(reviewItemID, maximum: 256)
+        }
+        guard commandFieldsAreValid else {
+            return .invalidEnvelope("command identifiers and text must be non-empty and bounded")
+        }
+        return nil
+    }
+
+    private func canonicalRequestBody(_ envelope: AgentCommandEnvelope) throws -> Data {
+        struct Body: Codable {
+            let version: Int
+            let projectRoot: String
+            let assertedThreadID: String?
+            let reason: String
+            let command: AgentCommand
+        }
+        let body = Body(
+            version: envelope.version,
+            projectRoot: envelope.projectRoot,
+            assertedThreadID: envelope.assertedThreadID,
+            reason: envelope.reason,
+            command: envelope.command
+        )
+        let encoder = JSONEncoder()
+        encoder.outputFormatting = [.sortedKeys]
+        return try encoder.encode(body)
+    }
+
+    private func resultForCommand(_ command: AgentCommand, auditEventID: AuditEventID) -> AgentCommandResult {
+        switch command {
+        case let .upsertPhase(phaseID, _):
+            return .init(entityIDs: [phaseID], auditEventID: auditEventID, error: nil)
+        case let .upsertTicket(ticketID, _, _, _):
+            return .init(entityIDs: [ticketID], auditEventID: auditEventID, error: nil)
+        case let .transitionTicket(ticketID, _):
+            return .init(entityIDs: [ticketID], auditEventID: auditEventID, error: nil)
+        case let .setDependency(id, _, _, _),
+             let .recordBlocker(id, _, _),
+             let .addEvidence(id, _, _),
+             let .linkThread(id, _, _),
+             let .requestReview(id, _, _, _),
+             let .recordCompletion(id, _, _):
+            return .init(entityIDs: [id], auditEventID: auditEventID, error: nil)
+        case let .resolveBlocker(blockerID):
+            return .init(entityIDs: [blockerID], auditEventID: auditEventID, error: nil)
+        case let .resolveImportReview(reviewItemID), let .dismissImportReview(reviewItemID):
+            return .init(entityIDs: [reviewItemID], auditEventID: auditEventID, error: nil)
+        }
+    }
+
+    private static func apply(
+        _ command: AgentCommand,
+        project: AuthorizedProject,
+        connection: SQLiteConnection
+    ) throws {
+        let projectID = project.projectID
+        switch command {
+        case let .upsertPhase(phaseID, name):
+            try requireWritableID(phaseID, table: "phases", projectID: projectID, connection: connection)
+            try connection.execute(
+                "INSERT INTO phases (id, project_id, name) VALUES (?, ?, ?) ON CONFLICT(id) DO UPDATE SET name = excluded.name",
+                bindings: [.text(phaseID), .text(projectID.rawValue), .text(name)]
+            )
+        case let .upsertTicket(ticketID, phaseID, outcome, lane):
+            try requireProjectEntity(phaseID, table: "phases", projectID: projectID, connection: connection)
+            try requireWritableID(ticketID, table: "tickets", projectID: projectID, connection: connection)
+            try connection.execute(
+                "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET phase_id = excluded.phase_id, outcome = excluded.outcome, lane = excluded.lane",
+                bindings: [.text(ticketID), .text(projectID.rawValue), .text(phaseID), .text(outcome), .text(lane.rawValue)]
+            )
+        case let .transitionTicket(ticketID, lane):
+            try requireProjectEntity(ticketID, table: "tickets", projectID: projectID, connection: connection)
+            try connection.execute(
+                "UPDATE tickets SET lane = ? WHERE project_id = ? AND id = ?",
+                bindings: [.text(lane.rawValue), .text(projectID.rawValue), .text(ticketID)]
+            )
+        case let .setDependency(id, kind, subjectID, dependsOnID):
+            let table = kind == .ticket ? "tickets" : "phases"
+            try requireProjectEntity(subjectID, table: table, projectID: projectID, connection: connection)
+            try requireProjectEntity(dependsOnID, table: table, projectID: projectID, connection: connection)
+            let dependencyTable = kind == .ticket ? "ticket_dependencies" : "phase_dependencies"
+            let subjectColumn = kind == .ticket ? "ticket_id" : "phase_id"
+            let dependencyColumn = kind == .ticket ? "depends_on_ticket_id" : "depends_on_phase_id"
+            try requireWritableID(id, table: dependencyTable, projectID: projectID, connection: connection)
+            try connection.execute(
+                "INSERT INTO \(dependencyTable) (id, project_id, \(subjectColumn), \(dependencyColumn)) VALUES (?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET \(subjectColumn) = excluded.\(subjectColumn), \(dependencyColumn) = excluded.\(dependencyColumn)",
+                bindings: [.text(id), .text(projectID.rawValue), .text(subjectID), .text(dependsOnID)]
+            )
+        case let .recordBlocker(id, ticketID, summary):
+            try requireProjectEntity(ticketID, table: "tickets", projectID: projectID, connection: connection)
+            try requireWritableID(id, table: "blockers", projectID: projectID, connection: connection)
+            try connection.execute(
+                "INSERT INTO blockers (id, project_id, ticket_id, summary, resolved_at) VALUES (?, ?, ?, ?, NULL) ON CONFLICT(id) DO UPDATE SET ticket_id = excluded.ticket_id, summary = excluded.summary, resolved_at = NULL",
+                bindings: [.text(id), .text(projectID.rawValue), .text(ticketID), .text(summary)]
+            )
+        case let .resolveBlocker(blockerID):
+            try requireProjectEntity(blockerID, table: "blockers", projectID: projectID, connection: connection)
+            try connection.execute(
+                "UPDATE blockers SET resolved_at = ? WHERE id = ? AND project_id = ?",
+                bindings: [.text(ISO8601DateFormatter().string(from: Date())), .text(blockerID), .text(projectID.rawValue)]
+            )
+        case let .addEvidence(id, ticketID, path):
+            if let ticketID {
+                try requireProjectEntity(ticketID, table: "tickets", projectID: projectID, connection: connection)
+            }
+            let resolvedPath = try authorizedEvidencePath(path, project: project)
+            try requireWritableID(id, table: "evidence", projectID: projectID, connection: connection)
+            try connection.execute(
+                "INSERT INTO evidence (id, project_id, ticket_id, path, is_available) VALUES (?, ?, ?, ?, 1) ON CONFLICT(id) DO UPDATE SET ticket_id = excluded.ticket_id, path = excluded.path, is_available = 1",
+                bindings: [.text(id), .text(projectID.rawValue), ticketID.map(SQLiteValue.text) ?? .null, .text(resolvedPath)]
+            )
+        case let .linkThread(id, ticketID, threadID):
+            try requireProjectEntity(ticketID, table: "tickets", projectID: projectID, connection: connection)
+            try requireProjectEntity(threadID, table: "observed_threads", projectID: projectID, connection: connection)
+            try requireWritableID(id, table: "thread_links", projectID: projectID, connection: connection)
+            try connection.execute(
+                "INSERT INTO thread_links (id, project_id, ticket_id, thread_id) VALUES (?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET ticket_id = excluded.ticket_id, thread_id = excluded.thread_id",
+                bindings: [.text(id), .text(projectID.rawValue), .text(ticketID), .text(threadID)]
+            )
+        case let .requestReview(id, ticketID, kind, summary):
+            if let ticketID {
+                try requireProjectEntity(ticketID, table: "tickets", projectID: projectID, connection: connection)
+            }
+            try requireWritableID(id, table: "review_items", projectID: projectID, connection: connection)
+            try connection.execute(
+                "INSERT INTO review_items (id, project_id, ticket_id, kind, summary, status) VALUES (?, ?, ?, ?, ?, 'open') ON CONFLICT(id) DO UPDATE SET ticket_id = excluded.ticket_id, kind = excluded.kind, summary = excluded.summary, status = 'open'",
+                bindings: [.text(id), .text(projectID.rawValue), ticketID.map(SQLiteValue.text) ?? .null, .text(kind), .text(summary)]
+            )
+        case let .recordCompletion(id, ticketID, summary):
+            try requireProjectEntity(ticketID, table: "tickets", projectID: projectID, connection: connection)
+            try requireWritableID(id, table: "completion_records", projectID: projectID, connection: connection)
+            try connection.execute(
+                "INSERT INTO completion_records (id, project_id, ticket_id, summary, created_at) VALUES (?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET ticket_id = excluded.ticket_id, summary = excluded.summary",
+                bindings: [.text(id), .text(projectID.rawValue), .text(ticketID), .text(summary), .text(ISO8601DateFormatter().string(from: Date()))]
+            )
+        case let .resolveImportReview(reviewItemID):
+            try updateImportReview(reviewItemID, status: "resolved", projectID: projectID, connection: connection)
+        case let .dismissImportReview(reviewItemID):
+            try updateImportReview(reviewItemID, status: "dismissed", projectID: projectID, connection: connection)
+        }
+    }
+
+    private static func requireWritableID(
+        _ id: String,
+        table: String,
+        projectID: ProjectID,
+        connection: SQLiteConnection
+    ) throws {
+        guard let existingProject = try connection.scalarText(
+            "SELECT project_id FROM \(table) WHERE id = ?",
+            bindings: [.text(id)]
+        ) else { return }
+        guard existingProject == projectID.rawValue else {
+            throw CommandValidation.crossProject("\(table) record \(id) belongs to another project")
+        }
+    }
+
+    private static func requireProjectEntity(
+        _ id: String,
+        table: String,
+        projectID: ProjectID,
+        connection: SQLiteConnection
+    ) throws {
+        guard let existingProject = try connection.scalarText(
+            "SELECT project_id FROM \(table) WHERE id = ?",
+            bindings: [.text(id)]
+        ) else {
+            throw CommandValidation.invalidReference("Unknown \(table) record \(id)")
+        }
+        guard existingProject == projectID.rawValue else {
+            throw CommandValidation.crossProject("\(table) record \(id) belongs to another project")
+        }
+    }
+
+    private static func authorizedEvidencePath(_ path: String, project: AuthorizedProject) throws -> String {
+        guard path.utf8.count <= 4_096 else {
+            throw CommandValidation.invalidReference("Evidence path exceeds 4096 UTF-8 bytes")
+        }
+        let rawURL = URL(fileURLWithPath: path, relativeTo: project.canonicalRoot)
+        let resolved = AuthorizedProject.canonicalize(rawURL)
+        guard FileManager.default.fileExists(atPath: resolved.path),
+              project.authorizedRoots.contains(where: { contains(resolved, within: $0) }) else {
+            throw CommandValidation.crossProject("Evidence must resolve inside an authorized project root")
+        }
+        return resolved.path
+    }
+
+    private static func contains(_ candidate: URL, within root: URL) -> Bool {
+        let candidateComponents = candidate.pathComponents
+        let rootComponents = root.pathComponents
+        return candidateComponents.count >= rootComponents.count
+            && Array(candidateComponents.prefix(rootComponents.count)) == rootComponents
+    }
+
+    private static func updateImportReview(
+        _ id: String,
+        status: String,
+        projectID: ProjectID,
+        connection: SQLiteConnection
+    ) throws {
+        try requireProjectEntity(id, table: "review_items", projectID: projectID, connection: connection)
+        guard try connection.scalarText(
+            "SELECT kind FROM review_items WHERE id = ?",
+            bindings: [.text(id)]
+        ) == "import" else {
+            throw CommandValidation.invalidReference("Review item \(id) is not an import review")
+        }
+        try connection.execute(
+            "UPDATE review_items SET status = ? WHERE id = ? AND project_id = ?",
+            bindings: [.text(status), .text(id), .text(projectID.rawValue)]
+        )
+    }
+
+    private static func map(_ error: Error) -> AgentCommandError {
+        if let validation = error as? CommandValidation {
+            switch validation {
+            case let .invalidReference(message): return .invalidReference(message)
+            case let .crossProject(message): return .crossProjectReference(message)
+            case let .cycle(message): return .dependencyCycle(message)
+            }
+        }
+        if let sqlite = error as? SQLiteError {
+            if sqlite.message.localizedCaseInsensitiveContains("cycle") {
+                return .dependencyCycle(sqlite.message)
+            }
+            if sqlite.message.localizedCaseInsensitiveContains("foreign key") {
+                return .invalidReference(sqlite.message)
+            }
+        }
+        return .internalFailure(error.localizedDescription)
+    }
+}
+
+private enum DispatchControl: Error, Sendable {
+    case replay(AgentCommandResult)
+    case requestIDReused
+}
+
+private enum CommandValidation: Error, Sendable {
+    case invalidReference(String)
+    case crossProject(String)
+    case cycle(String)
+}
diff --git a/ReleaseRadarCore/Models/DeliveryModels.swift b/ReleaseRadarCore/Models/DeliveryModels.swift
index a28d0c6..82944ce 100644
--- a/ReleaseRadarCore/Models/DeliveryModels.swift
+++ b/ReleaseRadarCore/Models/DeliveryModels.swift
@@ -20,35 +20,47 @@ public struct NotificationEventID: DeliveryRecordID { public let rawValue: Strin
 extension ProjectID: DeliveryRecordID {}
 
 public enum TicketLane: String, Codable, CaseIterable, Sendable {
     case backlog
     case inProgress = "in_progress"
     case needsReview = "needs_review"
     case blocked
     case accepted
 }
 
+public enum ThreadAttribution: String, Codable, CaseIterable, Sendable {
+    case none
+    case asserted
+    case verified
+}
+
 public struct DeliveryActor: Codable, Equatable, Sendable {
     public let id: String
     public let threadID: String?
+    public let threadAttribution: ThreadAttribution
 
-    public init(id: String, threadID: String? = nil) {
+    public init(
+        id: String,
+        threadID: String? = nil,
+        threadAttribution: ThreadAttribution? = nil
+    ) {
         self.id = id
         self.threadID = threadID
+        self.threadAttribution = threadAttribution ?? (threadID == nil ? .none : .asserted)
     }
 }
 
 public struct ProjectRecord: Codable, Equatable, Sendable { public let id: ProjectID; public let name: String }
 public struct ProjectRootRecord: Codable, Equatable, Sendable { public let id: ProjectRootID; public let projectID: ProjectID; public let path: String }
 public struct PhaseRecord: Codable, Equatable, Sendable { public let id: PhaseID; public let projectID: ProjectID; public let name: String }
 public struct TicketRecord: Codable, Equatable, Sendable { public let id: TicketID; public let projectID: ProjectID; public let phaseID: PhaseID; public let outcome: String; public let lane: TicketLane }
 public struct PhaseDependencyRecord: Codable, Equatable, Sendable { public let id: PhaseDependencyID; public let projectID: ProjectID; public let phaseID: PhaseID; public let dependsOnPhaseID: PhaseID }
 public struct TicketDependencyRecord: Codable, Equatable, Sendable { public let id: TicketDependencyID; public let projectID: ProjectID; public let ticketID: TicketID; public let dependsOnTicketID: TicketID }
 public struct BlockerRecord: Codable, Equatable, Sendable { public let id: BlockerID; public let projectID: ProjectID; public let ticketID: TicketID; public let summary: String }
 public struct EvidenceRecord: Codable, Equatable, Sendable { public let id: EvidenceID; public let projectID: ProjectID; public let ticketID: TicketID?; public let path: String; public let isAvailable: Bool }
 public struct ThreadLinkRecord: Codable, Equatable, Sendable { public let id: ThreadLinkID; public let projectID: ProjectID; public let ticketID: TicketID; public let threadID: ObservedThreadID }
 public struct ThreadExclusionRecord: Codable, Equatable, Sendable { public let id: ThreadExclusionID; public let projectID: ProjectID; public let threadID: String; public let reason: String }
 public struct ObservedThreadRecord: Codable, Equatable, Sendable { public let id: ObservedThreadID; public let projectID: ProjectID; public let status: String; public let lastObservedAt: Date }
 public struct ObservedGoalRecord: Codable, Equatable, Sendable { public let id: ObservedGoalID; public let projectID: ProjectID; public let threadID: ObservedThreadID; public let status: String; public let text: String; public let lastObservedAt: Date }
 public struct ReviewItemRecord: Codable, Equatable, Sendable { public let id: ReviewItemID; public let projectID: ProjectID; public let ticketID: TicketID?; public let kind: String; public let summary: String }
-public struct AuditEventRecord: Codable, Equatable, Sendable { public let id: AuditEventID; public let actorID: String; public let threadID: String?; public let reason: String; public let createdAt: Date }
+public struct AuditEventRecord: Codable, Equatable, Sendable { public let id: AuditEventID; public let actorID: String; public let threadID: String?; public let threadAttribution: ThreadAttribution; public let reason: String; public let createdAt: Date }
 public struct NotificationEventRecord: Codable, Equatable, Sendable { public let id: NotificationEventID; public let fingerprint: String; public let state: String; public let ticketID: TicketID?; public let goalID: ObservedGoalID? }
diff --git a/ReleaseRadarCore/Store/DeliveryStore.swift b/ReleaseRadarCore/Store/DeliveryStore.swift
index 0d7160d..3297340 100644
--- a/ReleaseRadarCore/Store/DeliveryStore.swift
+++ b/ReleaseRadarCore/Store/DeliveryStore.swift
@@ -71,38 +71,53 @@ public actor DeliveryStore {
                 preMigrationSnapshotURL: FileManager.default.fileExists(atPath: snapshotURL.path) ? snapshotURL : nil,
                 message: error.localizedDescription
             ))
         }
     }
 
     public func transact<T: Sendable>(
         actor: DeliveryActor,
         reason: String,
         _ body: @Sendable (SQLiteConnection) throws -> T
+    ) throws -> T {
+        try transact(
+            actor: actor,
+            reason: reason,
+            auditEventID: .init(rawValue: UUID().uuidString),
+            body
+        )
+    }
+
+    public func transact<T: Sendable>(
+        actor: DeliveryActor,
+        reason: String,
+        auditEventID: AuditEventID,
+        _ body: @Sendable (SQLiteConnection) throws -> T
     ) throws -> T {
         let connection = try availableConnection()
         try connection.execute("BEGIN IMMEDIATE TRANSACTION")
         let scopedConnection = connection.makeScopedConnection(access: .transaction)
         defer { scopedConnection.invalidate() }
         do {
             let result = try connection.withTransactionCallbackRestrictions {
                 try body(scopedConnection)
             }
             guard connection.isInTransaction else {
                 throw SQLiteError(code: SQLITE_MISUSE, message: "The transaction callback ended the store-owned transaction")
             }
             try connection.execute(
-                "INSERT INTO audit_events (id, actor_id, thread_id, reason, created_at) VALUES (?, ?, ?, ?, ?)",
+                "INSERT INTO audit_events (id, actor_id, thread_id, thread_attribution, reason, created_at) VALUES (?, ?, ?, ?, ?, ?)",
                 bindings: [
-                    .text(UUID().uuidString),
+                    .text(auditEventID.rawValue),
                     .text(actor.id),
                     actor.threadID.map(SQLiteValue.text) ?? .null,
+                    .text(actor.threadAttribution.rawValue),
                     .text(reason),
                     .text(ISO8601DateFormatter().string(from: Date())),
                 ]
             )
             try connection.execute("COMMIT")
             return result
         } catch {
             try? connection.execute("ROLLBACK")
             throw error
         }
diff --git a/ReleaseRadarCore/Store/StoreMigrations.swift b/ReleaseRadarCore/Store/StoreMigrations.swift
index 01fdadb..dc07e78 100644
--- a/ReleaseRadarCore/Store/StoreMigrations.swift
+++ b/ReleaseRadarCore/Store/StoreMigrations.swift
@@ -1,26 +1,31 @@
 import Foundation
 
 enum StoreMigrations {
-    static let currentVersion: Int64 = 1
+    static let currentVersion: Int64 = 2
 
     static func migrate(_ connection: SQLiteConnection) throws {
         let version = try connection.scalarInt("PRAGMA user_version") ?? 0
         guard version <= currentVersion else {
             throw StoreError.unsupportedSchemaVersion(found: version, supported: currentVersion)
         }
         guard version < currentVersion else { return }
 
         try connection.execute("BEGIN EXCLUSIVE TRANSACTION")
         do {
-            try connection.executeScript(schemaVersion1)
-            try connection.execute("PRAGMA user_version = 1")
+            if version < 1 {
+                try connection.executeScript(schemaVersion1)
+            }
+            if version < 2 {
+                try connection.executeScript(schemaVersion2)
+            }
+            try connection.execute("PRAGMA user_version = \(currentVersion)")
             try connection.execute("COMMIT")
         } catch {
             try? connection.execute("ROLLBACK")
             throw error
         }
     }
 
     private static let schemaVersion1 = """
     CREATE TABLE projects (
         id TEXT PRIMARY KEY NOT NULL,
@@ -196,11 +201,33 @@ enum StoreMigrations {
     CREATE TABLE notification_events (
         id TEXT PRIMARY KEY NOT NULL,
         fingerprint TEXT NOT NULL UNIQUE,
         state TEXT NOT NULL,
         ticket_id TEXT REFERENCES tickets(id) ON DELETE SET NULL,
         goal_id TEXT REFERENCES observed_goals(id) ON DELETE SET NULL,
         provider_receipt TEXT,
         acknowledged_at TEXT
     );
     """
+
+    private static let schemaVersion2 = """
+    ALTER TABLE audit_events ADD COLUMN thread_attribution TEXT NOT NULL DEFAULT 'none'
+        CHECK (thread_attribution IN ('none', 'asserted', 'verified'));
+    ALTER TABLE blockers ADD COLUMN resolved_at TEXT;
+    ALTER TABLE review_items ADD COLUMN status TEXT NOT NULL DEFAULT 'open'
+        CHECK (status IN ('open', 'resolved', 'dismissed'));
+    CREATE TABLE completion_records (
+        id TEXT PRIMARY KEY NOT NULL,
+        project_id TEXT NOT NULL,
+        ticket_id TEXT NOT NULL,
+        summary TEXT NOT NULL,
+        created_at TEXT NOT NULL,
+        FOREIGN KEY(project_id, ticket_id) REFERENCES tickets(project_id, id) ON DELETE CASCADE
+    );
+    CREATE TABLE agent_command_requests (
+        request_id TEXT PRIMARY KEY NOT NULL,
+        request_body BLOB NOT NULL,
+        result_data BLOB NOT NULL,
+        created_at TEXT NOT NULL
+    );
+    """
 }
diff --git a/ReleaseRadarIntegration/AgentBridgeApplicationHost.swift b/ReleaseRadarIntegration/AgentBridgeApplicationHost.swift
new file mode 100644
index 0000000..ea3f4af
--- /dev/null
+++ b/ReleaseRadarIntegration/AgentBridgeApplicationHost.swift
@@ -0,0 +1,266 @@
+import Foundation
+import ReleaseRadarCore
+import ServiceManagement
+
+enum AgentBridgeApplicationError: Error, LocalizedError, Equatable {
+    case requiresApproval
+    case launchDenied
+    case notFound
+    case registrationFailed(String)
+    case connectFailed(String)
+
+    var errorDescription: String? {
+        switch self {
+        case .requiresApproval:
+            "Release Radar Bridge Agent requires owner approval in System Settings > General > Login Items & Extensions."
+        case .launchDenied:
+            "Release Radar Bridge Agent launch is denied; enable it in System Settings > General > Login Items & Extensions."
+        case .notFound:
+            "Release Radar Bridge Agent is unavailable because its packaged LaunchAgent plist was not found."
+        case let .registrationFailed(message):
+            "Release Radar Bridge Agent registration failed: \(message)"
+        case let .connectFailed(message):
+            "Release Radar Bridge Agent connection failed: \(message)"
+        }
+    }
+}
+
+final class AgentBridgeApplicationHost: @unchecked Sendable {
+    private let service: SMAppService
+    private let callback: AgentBridgeAppCallback
+    private var connection: NSXPCConnection?
+    private var registeredHere = false
+
+    private init(dispatcher: AgentCommandDispatcher) {
+        service = .agent(plistName: ReleaseRadarBridgeTransport.launchAgentPlistName)
+        callback = AgentBridgeAppCallback(dispatcher: dispatcher)
+    }
+
+    static func start(databaseURL: URL = DeliveryStore.applicationSupportDatabaseURL()) async throws -> AgentBridgeApplicationHost {
+        let store = DeliveryStore(databaseURL: databaseURL)
+        let projects = try await loadAuthorizedProjects(from: store)
+        let dispatcher = AgentCommandDispatcher(
+            store: store,
+            projectRegistry: InMemoryAuthorizedProjectRegistry(projects: projects)
+        )
+        let host = AgentBridgeApplicationHost(dispatcher: dispatcher)
+        do {
+            try host.registerIfNeeded()
+            try await host.connect()
+            return host
+        } catch {
+            host.disconnectCallback()
+            try? host.rollbackRegistration()
+            throw error
+        }
+    }
+
+    func disconnectCallback() {
+        connection?.invalidate()
+        connection = nil
+    }
+
+    func unregister() throws {
+        try unregisterService()
+    }
+
+    private func rollbackRegistration() throws {
+        guard registeredHere else { return }
+        try unregisterService()
+    }
+
+    private func unregisterService() throws {
+        do {
+            try service.unregister()
+            registeredHere = false
+        } catch {
+            throw AgentBridgeApplicationError.registrationFailed(error.localizedDescription)
+        }
+    }
+
+    private func registerIfNeeded() throws {
+        switch service.status {
+        case .notRegistered, .notFound:
+            do {
+                try service.register()
+                registeredHere = true
+            } catch {
+                throw AgentBridgeApplicationError.registrationFailed(error.localizedDescription)
+            }
+        case .enabled:
+            break
+        case .requiresApproval:
+            throw AgentBridgeApplicationError.requiresApproval
+        @unknown default:
+            throw AgentBridgeApplicationError.registrationFailed("Unknown ServiceManagement status")
+        }
+
+        switch service.status {
+        case .enabled:
+            return
+        case .requiresApproval:
+            throw AgentBridgeApplicationError.requiresApproval
+        case .notFound:
+            throw AgentBridgeApplicationError.notFound
+        case .notRegistered:
+            throw AgentBridgeApplicationError.registrationFailed("Service remained unregistered")
+        @unknown default:
+            throw AgentBridgeApplicationError.registrationFailed("Unknown ServiceManagement status")
+        }
+    }
+
+    private func connect() async throws {
+        guard let brokerRequirement = ReleaseRadarBridgeTransport.brokerRequirement else {
+            throw AgentBridgeApplicationError.connectFailed("Invalid broker signing requirement")
+        }
+        let connection = NSXPCConnection(
+            machServiceName: ReleaseRadarBridgeTransport.appMachService,
+            options: []
+        )
+        connection.remoteObjectInterface = NSXPCInterface(with: ReleaseRadarAppBrokerXPC.self)
+        connection.exportedInterface = NSXPCInterface(with: ReleaseRadarAppCallbackXPC.self)
+        connection.exportedObject = callback
+        connection.setCodeSigningRequirement(brokerRequirement)
+        connection.resume()
+        self.connection = connection
+
+        do {
+            let returnedVersion = try await awaitRegistration(on: connection)
+            guard returnedVersion == ReleaseRadarBridgeTransport.version else {
+                throw AgentBridgeApplicationError.connectFailed("Bridge version mismatch")
+            }
+        } catch {
+            connection.invalidate()
+            self.connection = nil
+            switch service.status {
+            case .requiresApproval:
+                throw AgentBridgeApplicationError.launchDenied
+            case .notFound:
+                throw AgentBridgeApplicationError.notFound
+            default:
+                if let applicationError = error as? AgentBridgeApplicationError {
+                    throw applicationError
+                }
+                throw AgentBridgeApplicationError.connectFailed(error.localizedDescription)
+            }
+        }
+    }
+
+    private func awaitRegistration(on connection: NSXPCConnection) async throws -> Int {
+        try await withCheckedThrowingContinuation { continuation in
+            let gate = AgentBridgeContinuationGate(continuation)
+            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
+                gate.resume(throwing: AgentBridgeApplicationError.connectFailed(error.localizedDescription))
+            }) as? ReleaseRadarAppBrokerXPC else {
+                gate.resume(throwing: AgentBridgeApplicationError.connectFailed("Broker proxy unavailable"))
+                return
+            }
+            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
+                gate.resume(throwing: AgentBridgeApplicationError.connectFailed("Broker registration timed out"))
+            }
+            proxy.registerApp(ReleaseRadarBridgeTransport.version) { version in
+                gate.resume(returning: version)
+            }
+        }
+    }
+
+    private static func loadAuthorizedProjects(from store: DeliveryStore) async throws -> [AuthorizedProject] {
+        try await store.read { connection in
+            var rootsByProject: [String: [URL]] = [:]
+            var offset: Int64 = 0
+            while let row = try connection.row(
+                "SELECT project_id, path FROM project_roots ORDER BY project_id, id LIMIT 1 OFFSET ?",
+                bindings: [.integer(offset)]
+            ) {
+                guard case let .text(projectID)? = row["project_id"],
+                      case let .text(path)? = row["path"]
+                else {
+                    throw AgentBridgeApplicationError.connectFailed("Invalid persisted project root")
+                }
+                rootsByProject[projectID, default: []].append(URL(fileURLWithPath: path))
+                offset += 1
+            }
+            return rootsByProject.compactMap { projectID, roots in
+                guard let canonicalRoot = roots.first else { return nil }
+                return AuthorizedProject(
+                    projectID: ProjectID(rawValue: projectID),
+                    canonicalRoot: canonicalRoot,
+                    authorizedRoots: roots
+                )
+            }
+        }
+    }
+}
+
+private final class AgentBridgeAppCallback: NSObject, ReleaseRadarAppCallbackXPC, @unchecked Sendable {
+    private let dispatcher: AgentCommandDispatcher
+
+    init(dispatcher: AgentCommandDispatcher) {
+        self.dispatcher = dispatcher
+    }
+
+    func dispatch(
+        _ version: Int,
+        envelope data: Data,
+        deadline: TimeInterval,
+        withReply reply: @escaping (Data) -> Void
+    ) {
+        let replyGate = AgentBridgeDataReply(reply)
+        guard version == ReleaseRadarBridgeTransport.version,
+              data.count <= ReleaseRadarBridgeTransport.maximumEnvelopeBytes,
+              deadline > Date().timeIntervalSince1970,
+              ReleaseRadarBridgeTransport.envelopeVersion(in: data) == ReleaseRadarBridgeTransport.version,
+              let envelope = try? JSONDecoder().decode(AgentCommandEnvelope.self, from: data)
+        else {
+            if let found = ReleaseRadarBridgeTransport.envelopeVersion(in: data),
+               found != ReleaseRadarBridgeTransport.version {
+                replyGate.send(ReleaseRadarBridgeTransport.unsupportedVersionResultData(found: found))
+            } else {
+                replyGate.send(ReleaseRadarBridgeTransport.appUnavailableResultData())
+            }
+            return
+        }
+
+        Task {
+            let result = await dispatcher.dispatch(envelope)
+            replyGate.send((try? JSONEncoder().encode(result)) ?? ReleaseRadarBridgeTransport.appUnavailableResultData())
+        }
+    }
+}
+
+private final class AgentBridgeDataReply: @unchecked Sendable {
+    private let callback: (Data) -> Void
+
+    init(_ callback: @escaping (Data) -> Void) {
+        self.callback = callback
+    }
+
+    func send(_ data: Data) {
+        callback(data)
+    }
+}
+
+private final class AgentBridgeContinuationGate: @unchecked Sendable {
+    private let lock = NSLock()
+    private var continuation: CheckedContinuation<Int, Error>?
+
+    init(_ continuation: CheckedContinuation<Int, Error>) {
+        self.continuation = continuation
+    }
+
+    func resume(returning value: Int) {
+        take()?.resume(returning: value)
+    }
+
+    func resume(throwing error: Error) {
+        take()?.resume(throwing: error)
+    }
+
+    private func take() -> CheckedContinuation<Int, Error>? {
+        lock.lock()
+        defer { lock.unlock() }
+        let result = continuation
+        continuation = nil
+        return result
+    }
+}
diff --git a/ReleaseRadarTests/AgentBridgeAcceptanceTests.swift b/ReleaseRadarTests/AgentBridgeAcceptanceTests.swift
new file mode 100644
index 0000000..e71cae5
--- /dev/null
+++ b/ReleaseRadarTests/AgentBridgeAcceptanceTests.swift
@@ -0,0 +1,311 @@
+import Foundation
+import XCTest
+@testable import ReleaseRadarCore
+
+final class AgentBridgeAcceptanceTests: XCTestCase {
+    func testValidTransitionCommitsAuditAndDurableReplayReturnsOriginalResult() async throws {
+        let fixture = try await makeFixture()
+        let requestID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
+        let envelope = AgentCommandEnvelope(
+            version: 1,
+            requestID: requestID,
+            projectRoot: fixture.projectRoot.path,
+            assertedThreadID: "asserted-thread",
+            reason: "Move RR-03 into implementation",
+            command: .transitionTicket(ticketID: "RR-03", lane: .inProgress)
+        )
+
+        let first = await fixture.dispatcher.dispatch(envelope)
+        let relaunchedDispatcher = AgentCommandDispatcher(
+            store: DeliveryStore(databaseURL: fixture.databaseURL),
+            projectRegistry: fixture.registry
+        )
+        let replay = await relaunchedDispatcher.dispatch(envelope)
+
+        XCTAssertNil(first.error)
+        XCTAssertEqual(first.entityIDs, ["RR-03"])
+        XCTAssertNotNil(first.auditEventID)
+        XCTAssertEqual(replay, first)
+
+        let state = try await fixture.store.read { connection in
+            (
+                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-03'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Move RR-03 into implementation'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests WHERE request_id = ?", bindings: [.text(requestID.uuidString)]),
+                try connection.scalarText("SELECT thread_attribution FROM audit_events WHERE reason = 'Move RR-03 into implementation'")
+            )
+        }
+        XCTAssertEqual(state.0, TicketLane.inProgress.rawValue)
+        XCTAssertEqual(state.1, 1)
+        XCTAssertEqual(state.2, 1)
+        XCTAssertEqual(state.3, ThreadAttribution.asserted.rawValue)
+    }
+
+    func testApprovedCommandsPersistOnlyTheirBoundedDeliveryRecords() async throws {
+        let fixture = try await makeFixture()
+        let evidenceURL = fixture.projectRoot.appendingPathComponent("evidence.txt")
+        try Data("proof".utf8).write(to: evidenceURL)
+        let commands: [AgentCommand] = [
+            .upsertPhase(phaseID: "phase-2", name: "Launch"),
+            .upsertTicket(ticketID: "RR-04", phaseID: "phase-2", outcome: "Onboard projects", lane: .backlog),
+            .setDependency(id: "dependency-1", kind: .ticket, subjectID: "RR-04", dependsOnID: "RR-03"),
+            .recordBlocker(id: "blocker-1", ticketID: "RR-04", summary: "Needs owner folder"),
+            .resolveBlocker(blockerID: "blocker-1"),
+            .addEvidence(id: "evidence-1", ticketID: "RR-04", path: evidenceURL.path),
+            .linkThread(id: "link-1", ticketID: "RR-04", threadID: "verified-thread"),
+            .requestReview(id: "review-1", ticketID: "RR-04", kind: "agent_request", summary: "Validate folder scope"),
+            .recordCompletion(id: "completion-1", ticketID: "RR-04", summary: "Onboarding implemented"),
+            .resolveImportReview(reviewItemID: "import-review-resolve"),
+            .dismissImportReview(reviewItemID: "import-review-dismiss"),
+        ]
+
+        for (index, command) in commands.enumerated() {
+            let result = await fixture.dispatcher.dispatch(.init(
+                version: 1,
+                requestID: UUID(uuidString: String(format: "22222222-2222-4222-8222-%012d", index + 1))!,
+                projectRoot: fixture.projectRoot.path,
+                reason: "Exercise approved command \(index + 1)",
+                command: command
+            ))
+            XCTAssertNil(result.error, "Command \(index + 1) failed: \(String(describing: result.error))")
+            XCTAssertNotNil(result.auditEventID)
+        }
+
+        let state = try await fixture.store.read { connection in
+            (
+                try connection.scalarText("SELECT name FROM phases WHERE id = 'phase-2'"),
+                try connection.scalarText("SELECT outcome FROM tickets WHERE id = 'RR-04'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM ticket_dependencies WHERE id = 'dependency-1'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM blockers WHERE id = 'blocker-1' AND resolved_at IS NOT NULL"),
+                try connection.scalarText("SELECT path FROM evidence WHERE id = 'evidence-1'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM thread_links WHERE id = 'link-1'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM review_items WHERE id = 'review-1' AND status = 'open'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM completion_records WHERE id = 'completion-1'"),
+                try connection.scalarText("SELECT status FROM review_items WHERE id = 'import-review-resolve'"),
+                try connection.scalarText("SELECT status FROM review_items WHERE id = 'import-review-dismiss'")
+            )
+        }
+        XCTAssertEqual(state.0, "Launch")
+        XCTAssertEqual(state.1, "Onboard projects")
+        XCTAssertEqual(state.2, 1)
+        XCTAssertEqual(state.3, 1)
+        XCTAssertEqual(state.4, evidenceURL.path)
+        XCTAssertEqual(state.5, 1)
+        XCTAssertEqual(state.6, 1)
+        XCTAssertEqual(state.7, 1)
+        XCTAssertEqual(state.8, "resolved")
+        XCTAssertEqual(state.9, "dismissed")
+    }
+
+    func testEmptyCommandIdentifierIsRejectedBeforeAnyWrite() async throws {
+        let fixture = try await makeFixture()
+        let before = try await counts(fixture.store)
+        let result = await fixture.dispatcher.dispatch(.init(
+            version: 1,
+            requestID: UUID(uuidString: "33333333-3333-4333-8333-333333333333")!,
+            projectRoot: fixture.projectRoot.path,
+            reason: "Must reject empty identifier",
+            command: .upsertPhase(phaseID: "", name: "Invalid")
+        ))
+
+        guard case .invalidEnvelope? = result.error else {
+            return XCTFail("Expected invalidEnvelope, got \(String(describing: result.error))")
+        }
+        let after = try await counts(fixture.store)
+        XCTAssertEqual(after, before)
+    }
+
+    func testInvalidCrossProjectAndCycleCommandsReturnStructuredErrorsWithFullRollback() async throws {
+        let fixture = try await makeFixture()
+        let baseline = try await counts(fixture.store)
+
+        let invalid = await fixture.dispatcher.dispatch(.init(
+            version: 1,
+            requestID: UUID(uuidString: "44444444-4444-4444-8444-444444444441")!,
+            projectRoot: fixture.projectRoot.path,
+            reason: "Reject missing ticket",
+            command: .transitionTicket(ticketID: "missing", lane: .blocked)
+        ))
+        guard case .invalidReference? = invalid.error else {
+            return XCTFail("Expected invalidReference, got \(String(describing: invalid.error))")
+        }
+        var after = try await counts(fixture.store)
+        XCTAssertEqual(after, baseline)
+
+        let crossProject = await fixture.dispatcher.dispatch(.init(
+            version: 1,
+            requestID: UUID(uuidString: "44444444-4444-4444-8444-444444444442")!,
+            projectRoot: fixture.projectRoot.path,
+            reason: "Reject another project's thread",
+            command: .linkThread(id: "bad-link", ticketID: "RR-03", threadID: "other-thread")
+        ))
+        guard case .crossProjectReference? = crossProject.error else {
+            return XCTFail("Expected crossProjectReference, got \(String(describing: crossProject.error))")
+        }
+        after = try await counts(fixture.store)
+        XCTAssertEqual(after, baseline)
+
+        for (id, command) in [
+            ("44444444-4444-4444-8444-444444444443", AgentCommand.upsertTicket(ticketID: "RR-04", phaseID: "phase-1", outcome: "Onboard", lane: .backlog)),
+            ("44444444-4444-4444-8444-444444444444", AgentCommand.setDependency(id: "dependency-1", kind: .ticket, subjectID: "RR-04", dependsOnID: "RR-03")),
+        ] {
+            let result = await fixture.dispatcher.dispatch(.init(
+                version: 1,
+                requestID: UUID(uuidString: id)!,
+                projectRoot: fixture.projectRoot.path,
+                reason: "Seed cycle boundary",
+                command: command
+            ))
+            XCTAssertNil(result.error)
+        }
+        let beforeCycle = try await counts(fixture.store)
+        let cycle = await fixture.dispatcher.dispatch(.init(
+            version: 1,
+            requestID: UUID(uuidString: "44444444-4444-4444-8444-444444444445")!,
+            projectRoot: fixture.projectRoot.path,
+            reason: "Reject dependency cycle",
+            command: .setDependency(id: "dependency-2", kind: .ticket, subjectID: "RR-03", dependsOnID: "RR-04")
+        ))
+        guard case .dependencyCycle? = cycle.error else {
+            return XCTFail("Expected dependencyCycle, got \(String(describing: cycle.error))")
+        }
+        after = try await counts(fixture.store)
+        XCTAssertEqual(after, beforeCycle)
+        let dependencyCount = try await fixture.store.read { connection in
+            try connection.scalarInt("SELECT COUNT(*) FROM ticket_dependencies")
+        }
+        XCTAssertEqual(dependencyCount, 1)
+    }
+
+    func testDifferingRequestIDReuseFailsWithoutChangingOriginalMutation() async throws {
+        let fixture = try await makeFixture()
+        let requestID = UUID(uuidString: "55555555-5555-4555-8555-555555555555")!
+        let accepted = AgentCommandEnvelope(
+            version: 1,
+            requestID: requestID,
+            projectRoot: fixture.projectRoot.path,
+            reason: "Accept ticket",
+            command: .transitionTicket(ticketID: "RR-03", lane: .accepted)
+        )
+        let changedReuse = AgentCommandEnvelope(
+            version: 1,
+            requestID: requestID,
+            projectRoot: fixture.projectRoot.path,
+            reason: "Reuse ID for different command",
+            command: .transitionTicket(ticketID: "RR-03", lane: .backlog)
+        )
+
+        let acceptedResult = await fixture.dispatcher.dispatch(accepted)
+        XCTAssertNil(acceptedResult.error)
+        let beforeReuse = try await counts(fixture.store)
+        let rejected = await fixture.dispatcher.dispatch(changedReuse)
+
+        XCTAssertEqual(rejected.error, .requestIDReused)
+        let afterReuse = try await counts(fixture.store)
+        XCTAssertEqual(afterReuse, beforeReuse)
+        let lane = try await fixture.store.read { connection in
+            try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-03'")
+        }
+        XCTAssertEqual(lane, TicketLane.accepted.rawValue)
+    }
+
+    func testVersionSizeRootAndEvidenceValidationRejectBeforeWriting() async throws {
+        let fixture = try await makeFixture()
+        let outsideFile = fixture.projectRoot.deletingLastPathComponent().appendingPathComponent("outside.txt")
+        try Data("outside".utf8).write(to: outsideFile)
+        let baseline = try await counts(fixture.store)
+        let cases: [(AgentCommandEnvelope, (AgentCommandError) -> Bool)] = [
+            (.init(version: 99, requestID: UUID(), projectRoot: fixture.projectRoot.path, reason: "Wrong version", command: .transitionTicket(ticketID: "RR-03", lane: .blocked)), {
+                if case .unsupportedVersion = $0 { return true }; return false
+            }),
+            (.init(version: 1, requestID: UUID(), projectRoot: fixture.projectRoot.path, reason: "x", command: .upsertTicket(ticketID: "large", phaseID: "phase-1", outcome: String(repeating: "x", count: 70_000), lane: .backlog)), {
+                if case .invalidEnvelope = $0 { return true }; return false
+            }),
+            (.init(version: 1, requestID: UUID(), projectRoot: fixture.projectRoot.path, assertedThreadID: "", reason: "Empty asserted thread", command: .transitionTicket(ticketID: "RR-03", lane: .blocked)), {
+                if case .invalidEnvelope = $0 { return true }; return false
+            }),
+            (.init(version: 1, requestID: UUID(), projectRoot: fixture.projectRoot.deletingLastPathComponent().path, reason: "Outside root", command: .transitionTicket(ticketID: "RR-03", lane: .blocked)), {
+                $0 == .unauthorizedProjectRoot
+            }),
+            (.init(version: 1, requestID: UUID(), projectRoot: fixture.projectRoot.path, reason: "Outside evidence", command: .addEvidence(id: "outside-evidence", ticketID: "RR-03", path: outsideFile.path)), {
+                if case .crossProjectReference = $0 { return true }; return false
+            }),
+        ]
+
+        for (envelope, matches) in cases {
+            let result = await fixture.dispatcher.dispatch(envelope)
+            guard let error = result.error, matches(error) else {
+                return XCTFail("Unexpected validation result: \(result)")
+            }
+            let after = try await counts(fixture.store)
+            XCTAssertEqual(after, baseline)
+        }
+    }
+
+    func testUnavailableAppStoreReturnsAppUnavailableAndPreservesOriginalBytes() async throws {
+        let fixture = try await makeFixture()
+        let corruptURL = fixture.databaseURL.deletingLastPathComponent().appendingPathComponent("corrupt.sqlite")
+        let bytes = Data("not sqlite".utf8)
+        try bytes.write(to: corruptURL)
+        let dispatcher = AgentCommandDispatcher(
+            store: DeliveryStore(databaseURL: corruptURL),
+            projectRegistry: fixture.registry
+        )
+
+        let result = await dispatcher.dispatch(.init(
+            version: 1,
+            requestID: UUID(),
+            projectRoot: fixture.projectRoot.path,
+            reason: "Must not write without app store",
+            command: .transitionTicket(ticketID: "RR-03", lane: .blocked)
+        ))
+
+        XCTAssertEqual(result.error, .appUnavailable)
+        XCTAssertEqual(try Data(contentsOf: corruptURL), bytes)
+    }
+
+    private struct Fixture {
+        let databaseURL: URL
+        let projectRoot: URL
+        let store: DeliveryStore
+        let registry: InMemoryAuthorizedProjectRegistry
+        let dispatcher: AgentCommandDispatcher
+    }
+
+    private func makeFixture() async throws -> Fixture {
+        let temporaryDirectory = FileManager.default.temporaryDirectory
+            .appendingPathComponent("ReleaseRadar-AgentBridgeTests-\(UUID().uuidString)", isDirectory: true)
+        let projectRoot = temporaryDirectory.appendingPathComponent("project", isDirectory: true)
+        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
+        let databaseURL = temporaryDirectory.appendingPathComponent("store.sqlite")
+        let store = DeliveryStore(databaseURL: databaseURL)
+        try await store.transact(actor: .init(id: "fixture"), reason: "Seed bridge fixture") { connection in
+            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-1', 'Release Radar')")
+            try connection.execute("INSERT INTO project_roots (id, project_id, path) VALUES ('root-1', 'project-1', ?)", bindings: [.text(projectRoot.path)])
+            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'project-1', 'MVP')")
+            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('RR-03', 'project-1', 'phase-1', 'Typed bridge', 'backlog')")
+            try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('verified-thread', 'project-1', 'running', '2026-08-23T12:00:00Z')")
+            try connection.execute("INSERT INTO review_items (id, project_id, kind, summary) VALUES ('import-review-resolve', 'project-1', 'import', 'Resolve me')")
+            try connection.execute("INSERT INTO review_items (id, project_id, kind, summary) VALUES ('import-review-dismiss', 'project-1', 'import', 'Dismiss me')")
+            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-2', 'Other')")
+            try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('other-thread', 'project-2', 'running', '2026-08-23T12:00:00Z')")
+        }
+        let registry = InMemoryAuthorizedProjectRegistry(projects: [
+            .init(projectID: .init(rawValue: "project-1"), canonicalRoot: projectRoot, authorizedRoots: [projectRoot]),
+        ])
+        let dispatcher = AgentCommandDispatcher(store: store, projectRegistry: registry)
+        return Fixture(databaseURL: databaseURL, projectRoot: projectRoot, store: store, registry: registry, dispatcher: dispatcher)
+    }
+
+    private func counts(_ store: DeliveryStore) async throws -> [Int64] {
+        try await store.read { connection in
+            [
+                try connection.scalarInt("SELECT COUNT(*) FROM phases") ?? -1,
+                try connection.scalarInt("SELECT COUNT(*) FROM tickets") ?? -1,
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events") ?? -1,
+                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests") ?? -1,
+            ]
+        }
+    }
+
+}
diff --git a/ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift b/ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift
new file mode 100644
index 0000000..bb62896
--- /dev/null
+++ b/ReleaseRadarTests/AgentBridgeTransportAcceptanceTests.swift
@@ -0,0 +1,229 @@
+import Foundation
+import ServiceManagement
+import XCTest
+@testable import ReleaseRadar
+@testable import ReleaseRadarCore
+
+@MainActor
+final class AgentBridgeTransportAcceptanceTests: XCTestCase {
+    func testPackagedSignedToolUsesRegisteredBrokerAndFailsClosedWithoutTheApp() async throws {
+        let fixture = try await makeTransportFixture()
+        let appDelegate = AppDelegate()
+        let host = try await appDelegate.startAgentBridge(databaseURL: fixture.databaseURL)
+        defer {
+            host.disconnectCallback()
+            try? host.unregister()
+        }
+
+        let packagedTool = Bundle.main.bundleURL
+            .appendingPathComponent("Contents/Helpers/ReleaseRadarAgentTools")
+        let wrongTool = Bundle.main.bundleURL
+            .deletingLastPathComponent()
+            .appendingPathComponent("ReleaseRadarWrongAgentTools")
+        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: packagedTool.path))
+        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: wrongTool.path))
+
+        let requestID = "77777777-7777-4777-8777-777777777777"
+        let arguments: [String: Any] = [
+            "version": 1,
+            "requestID": requestID,
+            "projectRoot": fixture.projectRoot.path,
+            "reason": "Prove the packaged signed transport",
+            "ticketID": "RR-03",
+            "lane": "in_progress",
+        ]
+
+        let first = try runTool(packagedTool, tool: "release_radar_transition_ticket", arguments: arguments)
+        let firstResult = try decodeCommandResult(first)
+        XCTAssertNil(firstResult.error)
+        XCTAssertNotNil(firstResult.auditEventID)
+
+        let replay = try runTool(packagedTool, tool: "release_radar_transition_ticket", arguments: arguments)
+        XCTAssertEqual(try decodeCommandResult(replay), firstResult)
+        var counts = try await transportCounts(fixture.store)
+        XCTAssertEqual(counts, [1, 1])
+
+        let rejectedPeer = try runTool(wrongTool, tool: "release_radar_transition_ticket", arguments: arguments)
+        XCTAssertEqual(jsonRPCErrorCode(rejectedPeer), -32001)
+        counts = try await transportCounts(fixture.store)
+        XCTAssertEqual(counts, [1, 1])
+
+        let wrongBridge = try runTool(
+            packagedTool,
+            tool: "release_radar_transition_ticket",
+            arguments: arguments,
+            environment: ["RELEASE_RADAR_BRIDGE_VERSION": "999"]
+        )
+        XCTAssertEqual(jsonRPCErrorCode(wrongBridge), -32001)
+        counts = try await transportCounts(fixture.store)
+        XCTAssertEqual(counts, [1, 1])
+
+        var wrongEnvelopeArguments = arguments
+        wrongEnvelopeArguments["version"] = 999
+        let wrongEnvelope = try runTool(
+            packagedTool,
+            tool: "release_radar_transition_ticket",
+            arguments: wrongEnvelopeArguments
+        )
+        let wrongEnvelopeResult = try decodeCommandResult(wrongEnvelope)
+        XCTAssertEqual(wrongEnvelopeResult.error, .unsupportedVersion(found: 999, supported: 1))
+        counts = try await transportCounts(fixture.store)
+        XCTAssertEqual(counts, [1, 1])
+
+        host.disconnectCallback()
+        let unavailable = try runTool(packagedTool, tool: "release_radar_transition_ticket", arguments: [
+            "version": 1,
+            "requestID": "88888888-8888-4888-8888-888888888888",
+            "projectRoot": fixture.projectRoot.path,
+            "reason": "Do not persist without the app callback",
+            "ticketID": "RR-03",
+            "lane": "blocked",
+        ])
+        XCTAssertEqual(try decodeCommandResult(unavailable).error, .appUnavailable)
+        counts = try await transportCounts(fixture.store)
+        XCTAssertEqual(counts, [1, 1])
+
+        try host.unregister()
+        switch SMAppService.agent(plistName: ReleaseRadarBridgeTransport.launchAgentPlistName).status {
+        case .notRegistered, .notFound:
+            break
+        default:
+            XCTFail("Explicit cleanup left the bridge registered")
+        }
+    }
+
+    private struct TransportFixture {
+        let databaseURL: URL
+        let projectRoot: URL
+        let store: DeliveryStore
+    }
+
+    private func makeTransportFixture() async throws -> TransportFixture {
+        let directory = FileManager.default.temporaryDirectory
+            .appendingPathComponent("ReleaseRadar-TransportTests-\(UUID().uuidString)", isDirectory: true)
+        let projectRoot = directory.appendingPathComponent("project", isDirectory: true)
+        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
+        let databaseURL = directory.appendingPathComponent("store.sqlite")
+        let store = DeliveryStore(databaseURL: databaseURL)
+        try await store.transact(actor: .init(id: "fixture"), reason: "Seed transport fixture") { connection in
+            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-1', 'Release Radar')")
+            try connection.execute(
+                "INSERT INTO project_roots (id, project_id, path) VALUES ('root-1', 'project-1', ?)",
+                bindings: [.text(projectRoot.path)]
+            )
+            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'project-1', 'MVP')")
+            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('RR-03', 'project-1', 'phase-1', 'Signed bridge', 'backlog')")
+        }
+        return .init(databaseURL: databaseURL, projectRoot: projectRoot, store: store)
+    }
+
+    private func runTool(
+        _ executableURL: URL,
+        tool: String,
+        arguments: [String: Any],
+        environment: [String: String] = [:]
+    ) throws -> [String: Any] {
+        let process = Process()
+        process.executableURL = executableURL
+        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, override in override }
+        let input = Pipe()
+        let output = Pipe()
+        let errors = Pipe()
+        process.standardInput = input
+        process.standardOutput = output
+        process.standardError = errors
+
+        let requests: [[String: Any]] = [
+            [
+                "jsonrpc": "2.0",
+                "id": 0,
+                "method": "initialize",
+                "params": [
+                    "protocolVersion": "2025-06-18",
+                    "capabilities": [:],
+                    "clientInfo": ["name": "ReleaseRadarTests", "version": "1"],
+                ],
+            ],
+            [
+                "jsonrpc": "2.0",
+                "id": 1,
+                "method": "tools/list",
+            ],
+            [
+                "jsonrpc": "2.0",
+                "id": 2,
+                "method": "tools/call",
+                "params": ["name": tool, "arguments": arguments],
+            ],
+        ]
+        let requestData = try requests.reduce(into: Data()) { data, request in
+            data.append(try JSONSerialization.data(withJSONObject: request))
+            data.append(0x0A)
+        }
+
+        try process.run()
+        input.fileHandleForWriting.write(requestData)
+        try input.fileHandleForWriting.close()
+        process.waitUntilExit()
+        let responseData = output.fileHandleForReading.readDataToEndOfFile()
+        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
+        guard process.terminationStatus == 0 else {
+            throw TransportTestError.invalidResponse(String(decoding: errorData, as: UTF8.self))
+        }
+        let responses = try responseData.split(separator: 0x0A).map { line -> [String: Any] in
+            guard let object = try JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else {
+                throw TransportTestError.invalidResponse(String(decoding: line, as: UTF8.self))
+            }
+            return object
+        }
+        guard let listResponse = responses.first(where: { ($0["id"] as? NSNumber)?.intValue == 1 }),
+              hasTypedToolSchema(listResponse),
+              let callResponse = responses.first(where: { ($0["id"] as? NSNumber)?.intValue == 2 })
+        else {
+            throw TransportTestError.invalidResponse(String(decoding: responseData, as: UTF8.self))
+        }
+        return callResponse
+    }
+
+    private func hasTypedToolSchema(_ response: [String: Any]) -> Bool {
+        guard let result = response["result"] as? [String: Any],
+              let tools = result["tools"] as? [[String: Any]],
+              tools.count == 12,
+              let transition = tools.first(where: { $0["name"] as? String == "release_radar_transition_ticket" }),
+              let schema = transition["inputSchema"] as? [String: Any],
+              let properties = schema["properties"] as? [String: Any],
+              let required = schema["required"] as? [String]
+        else { return false }
+        return Set(properties.keys) == ["version", "requestID", "projectRoot", "assertedThreadID", "reason", "ticketID", "lane"]
+            && Set(required) == ["version", "requestID", "projectRoot", "reason", "ticketID", "lane"]
+            && schema["additionalProperties"] as? Bool == false
+    }
+
+    private func decodeCommandResult(_ response: [String: Any]) throws -> AgentCommandResult {
+        guard let result = response["result"] as? [String: Any],
+              let content = result["content"] as? [[String: Any]],
+              let text = content.first?["text"] as? String,
+              let data = text.data(using: .utf8)
+        else {
+            throw TransportTestError.invalidResponse(String(describing: response))
+        }
+        return try JSONDecoder().decode(AgentCommandResult.self, from: data)
+    }
+
+    private func jsonRPCErrorCode(_ response: [String: Any]) -> Int? {
+        ((response["error"] as? [String: Any])?["code"] as? NSNumber)?.intValue
+    }
+
+    private func transportCounts(_ store: DeliveryStore) async throws -> [Int64] {
+        try await store.read { connection in
+            [
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events WHERE reason = 'Prove the packaged signed transport'") ?? -1,
+                try connection.scalarInt("SELECT COUNT(*) FROM agent_command_requests WHERE request_id = '77777777-7777-4777-8777-777777777777'") ?? -1,
+            ]
+        }
+    }
+}
+
+private enum TransportTestError: Error {
+    case invalidResponse(String)
+}
diff --git a/ReleaseRadarTests/StoreAcceptanceTests.swift b/ReleaseRadarTests/StoreAcceptanceTests.swift
index a7fbd31..93fa36a 100644
--- a/ReleaseRadarTests/StoreAcceptanceTests.swift
+++ b/ReleaseRadarTests/StoreAcceptanceTests.swift
@@ -365,21 +365,21 @@ final class StoreAcceptanceTests: XCTestCase {
                 try connection.scalarInt("SELECT COUNT(*) FROM audit_events"),
                 try connection.scalarInt("SELECT COUNT(*) FROM blockers")
             )
         }
         let relaunchedDatabase = try SQLiteConnection(url: databaseURL)
         let snapshot = try SQLiteConnection(url: DeliveryStore.preMigrationSnapshotURL(for: databaseURL))
 
         XCTAssertEqual(persisted.0, "Store")
         XCTAssertEqual(persisted.1, 1)
         XCTAssertEqual(persisted.2, 0)
-        XCTAssertEqual(try relaunchedDatabase.scalarInt("PRAGMA user_version"), 1)
+        XCTAssertEqual(try relaunchedDatabase.scalarInt("PRAGMA user_version"), 2)
         XCTAssertEqual(try snapshot.scalarText("SELECT value FROM legacy_marker"), "before-migration")
         XCTAssertEqual(try snapshot.scalarInt("PRAGMA user_version"), 0)
     }
 
     func testCorruptDatabaseOpensUnavailableAndLeavesOriginalBytesIntact() async throws {
         let databaseURL = try makeDatabaseURL()
         let originalBytes = Data("not-a-sqlite-database".utf8)
         try originalBytes.write(to: databaseURL)
 
         let store = DeliveryStore(databaseURL: databaseURL)
diff --git a/ReleaseRadarTransport/BridgeXPCContracts.swift b/ReleaseRadarTransport/BridgeXPCContracts.swift
new file mode 100644
index 0000000..9e4e40c
--- /dev/null
+++ b/ReleaseRadarTransport/BridgeXPCContracts.swift
@@ -0,0 +1,82 @@
+import Foundation
+import Security
+
+enum ReleaseRadarBridgeTransport {
+    static let version = 1
+    static let maximumEnvelopeBytes = 131_072
+    static let maximumLineBytes = 196_608
+    static let maximumDeadlineInterval: TimeInterval = 15
+
+    static let appMachService = "2UA854NLX4.com.rekonlabs.ReleaseRadar.bridge.app"
+    static let toolsMachService = "2UA854NLX4.com.rekonlabs.ReleaseRadar.bridge.tools"
+    static let launchAgentPlistName = "com.rekonlabs.ReleaseRadar.BridgeAgent.plist"
+
+    static let appRequirement = validatedRequirement(
+        "anchor apple generic and identifier \"com.rekonlabs.ReleaseRadar\" and certificate leaf[subject.OU] = \"2UA854NLX4\""
+    )
+    static let toolsRequirement = validatedRequirement(
+        "anchor apple generic and identifier \"com.rekonlabs.ReleaseRadarAgentTools\" and certificate leaf[subject.OU] = \"2UA854NLX4\""
+    )
+    static let brokerRequirement = validatedRequirement(
+        "anchor apple generic and identifier \"com.rekonlabs.ReleaseRadarBridgeAgent\" and certificate leaf[subject.OU] = \"2UA854NLX4\""
+    )
+
+    static func envelopeVersion(in data: Data) -> Int? {
+        guard data.count <= maximumEnvelopeBytes,
+              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
+              let number = object["version"] as? NSNumber
+        else { return nil }
+        return number.intValue
+    }
+
+    static func appUnavailableResultData() -> Data {
+        resultData(error: ["appUnavailable": [:]])
+    }
+
+    static func unsupportedVersionResultData(found: Int) -> Data {
+        resultData(error: [
+            "unsupportedVersion": ["found": found, "supported": version],
+        ])
+    }
+
+    private static func validatedRequirement(_ text: String) -> String? {
+        var requirement: SecRequirement?
+        guard SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess,
+              requirement != nil
+        else { return nil }
+        return text
+    }
+
+    private static func resultData(error: [String: Any]) -> Data {
+        (try? JSONSerialization.data(withJSONObject: [
+            "entityIDs": [],
+            "error": error,
+        ])) ?? Data()
+    }
+}
+
+@objc(ReleaseRadarToolsBrokerXPC)
+protocol ReleaseRadarToolsBrokerXPC {
+    func handshake(_ version: Int, withReply reply: @escaping (Int) -> Void)
+    func forward(
+        _ version: Int,
+        envelope: Data,
+        deadline: TimeInterval,
+        withReply reply: @escaping (Data) -> Void
+    )
+}
+
+@objc(ReleaseRadarAppBrokerXPC)
+protocol ReleaseRadarAppBrokerXPC {
+    func registerApp(_ version: Int, withReply reply: @escaping (Int) -> Void)
+}
+
+@objc(ReleaseRadarAppCallbackXPC)
+protocol ReleaseRadarAppCallbackXPC {
+    func dispatch(
+        _ version: Int,
+        envelope: Data,
+        deadline: TimeInterval,
+        withReply reply: @escaping (Data) -> Void
+    )
+}
diff --git a/docs/delivery/progress.md b/docs/delivery/progress.md
index 4fe430a..16be2a9 100644
--- a/docs/delivery/progress.md
+++ b/docs/delivery/progress.md
@@ -19,24 +19,24 @@ Deliver the signed native macOS MVP described by
 
 ## Repository
 
 - Local: `/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar`
 - Remote: `https://github.com/joeroberts/release-radar`
 - Branch: `codex/release-radar-mvp`
 - Pull requests: prohibited by owner direction for this goal.
 
 ## Current gate
 
-- Current task: RR-03 typed agent action bridge released by TPM and Delivery Manager.
-- Next eligible task: RR-03 typed agent action bridge.
-- Open product blockers: none.
-- Open operational risks: none.
+- Current task: RR-03 complete implementation is ready for independent code, QA, architecture, and security/privacy review.
+- Next eligible task: RR-03 independent review only. RR-04 is not eligible until every Required RR-03 finding is closed and the release gate records acceptance.
+- Open product blockers: no implementation blocker; the RR-03 independent review gate remains open.
+- Open operational risks: macOS may require owner approval for the packaged LaunchAgent on another machine; startup reports the required System Settings action explicitly and fails closed until enabled.
 
 ## Task ledger
 
 Each task entry records status, verification, reviews with Required/Optional/Out-of-scope classification, decisions, risks, stop-rule events, commit SHA, and the next eligible task before release.
 
 ### RR-01 — Standalone signed application foundation
 
 - Status: Accepted.
 - Commits: `487647a` scaffold, `50dab32` evidence, `ca09ba8` focused-test fix, `c3e5f79` fix evidence.
 - Verification: normal configured Debug signing build passed; `build_and_run.sh --verify` launched the app; build-for-testing and strict codesign verification passed; focused `AppRouteTests` completed with 2 passed, 0 failed/skipped.
@@ -62,10 +62,23 @@ Each task entry records status, verification, reviews with Required/Optional/Out
 - Reviews: Final recovery reviews are clean. Code Reviewer: ACCEPT, Required 0, Optional 0, Out of scope 0. QA: ACCEPT, 15/15 focused tests, 0 failures/skips, Required 0. Architect: APPROVED, ADR-001 deviation resolved, Required 0. Security/privacy: PASS, Required 0, Optional 0; an independent system-SQLite probe confirmed state-setting PRAGMAs are denied, ordinary SELECT remains available, and foreign-key enforcement remains enabled.
 - Decisions: The app remains the sole SQLite writer; all writes enter `DeliveryStore.transact` and receive an audit event; callbacks receive thread-bound leases invalidated on scope exit instead of the actor-owned connection; transaction callbacks deny transaction control and cannot access `audit_events`; the store verifies its transaction remains active before automatic audit insertion and commit; read callbacks now use a strict SQLite authorizer allowlist limited to SELECT, READ, and FUNCTION actions, denying PRAGMA and every connection/schema/transaction/mutation action by default; migrations are exclusive/atomic; a consistent snapshot is preserved before changing an existing non-current database; failure produces typed unavailable/recovery state without resetting authoritative data.
 - Risks: No open RR-02 Required finding. Later bridge/tool slices must preserve the app-only writer boundary and must not expose `SQLiteConnection` or database paths to agents.
 - Stop-rule events: The original read-boundary remediation stopped after two rounds when review found that the denylist still admitted SQLite connection-state mutation. A fresh recovery implementer preserved the existing lease, audit, and transaction protections and replaced only the read authorizer policy with the smaller fail-closed observational allowlist.
 - Next eligible task: RR-03 typed agent action bridge.
 
 ### RR-03 release gate
 
 - TPM: GO; RR-02 is technically accepted with all Required findings closed, scope controlled, and the recorded stop-rule recovery complete.
 - Delivery Manager: GO; RR-02 commits, focused verification, signed build, independent reviews, and stop-rule evidence are durable; RR-03 is dependency-safe and released to one fresh Implementer with no concurrent writer.
+
+### RR-03 — Typed agent action bridge
+
+- Status: Complete implementation; awaiting independent review. Not accepted or released.
+- Commits: `6b7262c` (`feat: add typed agent delivery actions`) and `fa8eea0` (`feat: add signed agent bridge transport`).
+- Implemented scope: the committed typed command/dispatcher core plus a packaged MCP stdio tool, sandboxed LaunchAgent broker, application-hosted callback, exact version/size/deadline bounds, same-user and pinned team/identifier signing requirements on every XPC hop, app lifecycle registration, explicit unavailable/approval errors, and fail-closed disconnect behavior. The broker/tool do not link `ReleaseRadarCore` or SQLite and cannot open the authoritative store.
+- TDD: the transport scenario began RED with no application host, then proved registration/launch, signed-peer checks, valid commit/audit, durable replay, identity/version/envelope rejection, app-disconnect no-write behavior, production startup wiring, cleanup ownership, and typed MCP discovery through focused RED→GREEN cycles. Detailed commands and logs are recorded in `.superpowers/sdd/2026-08-23-release-radar-mvp/task-3-report.md`.
+- Verification: a fresh normal Debug app build passed. Strict deep signing plus explicit app/broker/tool requirements passed; the broker had exactly sandbox + the approved app group, the tool was unsandboxed with no app group, no embedded profile existed, and `otool` showed no Core/SQLite dependency in either executable. The final combined run exercised byte-identical normal-package broker/tool binaries and passed 23/23 transport/core/store tests with 0 failures/skips. Cleanup left no registered service or exact helper process; diff checks passed.
+- Stop-rule recovery: the earlier anonymous-endpoint and app-owned listener attempts remain recorded as stopped and removed. The fresh recovery used the architect-approved minimal correction: a sandboxed broker with the same-team app group, an unsandboxed tool without the group, two team-prefixed Mach services, and no weaker fallback.
+- Required blocker: none in implementation. Independent RR-03 reviews are still required before acceptance or RR-04 release.
+- Reviews: not started for the complete slice; Required findings from code, QA, architecture, or security/privacy review will block acceptance.
+- Decisions/risks: preserve the app-only SQLite writer boundary. The app composes persisted authorized roots into the existing registry seam; the broker holds only the latest authenticated callback in memory. On machines where ServiceManagement returns `requiresApproval`, the app logs the explicit Login Items & Extensions owner action and does not weaken or bypass the gate.
+- Next eligible task: independent RR-03 code review, QA verification, architecture review, and security/privacy verification. RR-04 remains closed.
