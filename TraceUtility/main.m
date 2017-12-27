//
//  main.m
//  TraceUtility
//
//  Created by Qusic on 7/9/15.
//  Copyright (c) 2015 Qusic. All rights reserved.
//

#import "InstrumentsPrivateHeader.h"
#import <objc/runtime.h>

#define TUPrint(format, ...) CFShow((__bridge CFStringRef)[NSString stringWithFormat:format, ## __VA_ARGS__])
#define TUIvarCast(object, name, type) (*(type *)(void *)&((char *)(__bridge void *)object)[ivar_getOffset(class_getInstanceVariable(object_getClass(object), #name))])
#define TUIvar(object, name) TUIvarCast(object, name, id const)

// Workaround to fix search paths for Instruments plugins and packages.
static NSBundle *(*NSBundle_mainBundle_original)(id self, SEL _cmd);
static NSBundle *NSBundle_mainBundle_replaced(id self, SEL _cmd) {
    return [NSBundle bundleWithIdentifier:@"com.apple.dt.Instruments"];
}

static void __attribute__((constructor)) hook() {
    Method NSBundle_mainBundle = class_getClassMethod(NSBundle.class, @selector(mainBundle));
    NSBundle_mainBundle_original = (void *)method_getImplementation(NSBundle_mainBundle);
    method_setImplementation(NSBundle_mainBundle, (IMP)NSBundle_mainBundle_replaced);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Required. Each instrument is a plugin and we have to load them before we can process their data.
        
        [NSBundle bundleWithPath:@"/Applications/Xcode.app/Contents/Applications/Instruments.app"];
//        [NSBundle bundleWithPath:@"/Applications/Xcode.app"];
//        [NSBundle bundleWithPath:@"/Applications/Xcode.app/Contents/SharedFrameworks/SceneKit.framework"];
//        [NSBundle bundleWithPath:@"/Applications/Xcode.app/Contents/SharedFrameworks/ModelIO.framework"];
//        [NSBundle bundleWithPath:@"/Applications/Xcode.app/Contents/SharedFrameworks/PhysicsKit.framework"];
//        [NSBundle bundleWithPath:@"/Applications/Xcode.app/Contents/SharedFrameworks/Jet.framework"];
//        [NSBundle bundleWithPath:@"/Applications/Xcode.app/Contents/SharedFrameworks/SpriteKit.framework"];
//        [NSBundle bundleWithPath:@"/Applications/Xcode.app/Contents/SharedFrameworks/GameplayKit.framework"];
//        [NSBundle bundleWithPath:@"/Applications/Xcode.app/Contents/SharedFrameworks/DVTInstrumentsFoundation.framework"];
//        [NSBundle bundleWithPath:@"/Applications/Xcode.app/Contents/SharedFrameworks/DVTInstrumentsUtilities.framework"];
//        [NSBundle bundleWithPath:@"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform"];
//        [NSBundle bundleWithPath:@"/Applications/Xcode.app/Contents/Applications/Instruments.app/Contents/Frameworks/InstrumentsKit.framework"];
//        [NSBundle bundleWithPath:@""];
//        [NSBundle bundleWithPath:@""];
        
        
        // NSURL *url = [NSURL URLWithString:@"/Applications/Xcode.app"];
        // [NSBundle bundleWithURL:url];
        // [[NSBundle mainBundle] pathForResource:@"traceData" ofType:@"trace"];
        // [NSBundle bundleWithPath:@"/Applications/Xcode.app"];
        DVTInitializeSharedFrameworks();
        [DVTDeveloperPaths initializeApplicationDirectoryName:@"Instruments"];
        [XRInternalizedSettingsStore configureWithAdditionalURLs:nil];
        // TUPrint(PFTUserTemplateDirectory());
        
        
        if (PFTLoadPlugins()){
            TUPrint(@"yes");
        }else{
            TUPrint(@"no");
        };
        // TUPrint(PFTDeveloperDirectory());
        //PFTInstrumentsAppTemplates();
        PFTInstrumentPlugin *plg = [[PFTInstrumentPlugin alloc] init];
        // Instruments has its own subclass of NSDocumentController without overriding sharedDocumentController method.
        // We have to call this eagerly to make sure the correct document controller is initialized.
        [PFTDocumentController sharedDocumentController];

        // Open a trace document.
        // NSString *tracePath = NSProcessInfo.processInfo.arguments[1];
        NSString *tracePath = @"/Users/difeitang/Downloads/Instruments_activity.trace";
        
        
        NSString *traceTemplatePath = @"/Applications/Xcode.app/Contents/Applications/Instruments.app/Contents/Resources/templates/Metal System Trace.tracetemplate";
        
        NSError *erro = nil;
        PFTTraceDocument *template = [[PFTTraceDocument alloc] init];
        [template readFromURL:[NSURL fileURLWithPath:traceTemplatePath] ofType:@"Trace Template" error:&erro];
        
        
        
        // NSString *tracePath = @"/private/var/root/Downloads/Instruments_m2.trace";
        
        NSError *error = nil;
        
        PFTTraceDocument *document = [[PFTTraceDocument alloc] init];
        Class cls = PFTTraceDocument.class;
        // TUPrint(@"Version %d", class_getVersion(cls));
        [document readFromURL:[NSURL fileURLWithPath:tracePath] ofType:@"Trace Document" error:&error];
        
        //PFTTraceDocument *document = [[PFTTraceDocument alloc]initWithContentsOfURL:[NSURL fileURLWithPath:tracePath] ofType:@"Trace Document" error:&error];
        if (error) {
            TUPrint(@"Error: %@\n", error);
            return 1;
        }
        
        TUPrint(@"Trace: %@\n", tracePath);
        
        // List some useful metadata of the document.
        XRDevice *device = document.targetDevice;
        TUPrint(@"Device: %@ (%@ %@ %@)\n", device.deviceDisplayName, device.productType, device.productVersion, device.buildVersion);
        PFTProcess *process = document.defaultProcess;
        TUPrint(@"Process: %@ (%@)\n", process.displayName, process.bundleIdentifier);
        
        // Each trace document consists of data from several different instruments.
        XRTrace *trace = document.trace;
        for (XRInstrument *instrument in trace.allInstrumentsList.allInstruments) {
            TUPrint(@"\nInstrument: %@ (%@)\n", instrument.type.name, instrument.type.uuid);
            
            // Common routine to obtain the data container.
            if (![instrument isKindOfClass:XRLegacyInstrument.class]) {
                instrument.viewController = [[XRAnalysisCoreStandardController alloc]initWithInstrument:instrument document:document];
                TUPrint(@"----Legacy\n");
            }
            
            id<XRInstrumentViewController> controller = instrument.viewController;
            [controller instrumentDidChangeSwitches];
            [controller instrumentChangedTableRequirements];
            id<XRContextContainer> container = controller.detailContextContainer.contextRepresentation.container;
            
            // Each instrument can have multiple runs.
            NSArray<XRRun *> *runs = instrument.allRuns;
            if (runs.count == 0) {
                TUPrint(@"No data.\n");
                continue;
            }
            for (XRRun *run in runs) {
                TUPrint(@"Run #%@: %@\n", @(run.runNumber), run.displayName);
                instrument.currentRun = run;

                // Different instruments can have different data structure.
                // Here are some straightforward example code demonstrating how to process the data from several commonly used instruments.
                NSString *instrumentID = instrument.type.uuid;
                // TUPrint(@"UUID: %@\n", instrumentID);
                
                if ([instrumentID isEqualToString:@"com.apple.xray.instrument-type.coresampler2"]) {
                    // Time Profiler: print out all functions in descending order of self execution time.
                    XRCallTreeDetailView *callTreeView = (XRCallTreeDetailView *)container;
                    XRBacktraceRepository *backtraceRepository = callTreeView.backtraceRepository;
                    
                    static NSMutableArray<PFTCallTreeNode *> * (^ flattenTree)(PFTCallTreeNode *) = ^(PFTCallTreeNode *rootNode) { // Helper function to collect all tree nodes.
                        NSMutableArray *nodes = [NSMutableArray array];
                        if (rootNode) {
                            [nodes addObject:rootNode];
                            for (PFTCallTreeNode *node in rootNode.children) {
                                [nodes addObjectsFromArray:flattenTree(node)];
                            }
                        }
                        return nodes;
                    };
                    /*
                    NSMutableArray<PFTCallTreeNode *> *nodes = flattenTree(backtraceRepository.rootNode);
                    [nodes sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(@selector(terminals)) ascending:NO]]];
                    for (PFTCallTreeNode *node in nodes) {
                        TUPrint(@"%@ %@ %i ms\n", node.libraryName, node.symbolName, node.terminals);
                    }*/
                     
                }else if ([instrumentID isEqualToString:@"com.apple.xray.instrument-type.oa"]) {
                    // Allocations: print out the memory allocated during each second in descending order of the size.
                    XRObjectAllocInstrument *allocInstrument = (XRObjectAllocInstrument *)container;
                    [allocInstrument._topLevelContexts[2] display]; // 4 contexts: Statistics, Call Trees, Allocations List, Generations.
                    XRManagedEventArrayController *arrayController = TUIvar(TUIvar(allocInstrument, _objectListController), _ac);
                    NSMutableDictionary<NSNumber *, NSNumber *> *sizeGroupedByTime = [NSMutableDictionary dictionary];
                    for (XRObjectAllocEvent *event in arrayController.arrangedObjects) {
                        NSNumber *time = @(event.timestamp / NSEC_PER_SEC);
                        NSNumber *size = @(sizeGroupedByTime[time].integerValue + event.size);
                        sizeGroupedByTime[time] = size;
                    }
                    NSArray<NSNumber *> *sortedTime = [sizeGroupedByTime.allKeys sortedArrayUsingComparator:^(NSNumber *time1, NSNumber *time2) {
                        return [sizeGroupedByTime[time2] compare:sizeGroupedByTime[time1]];
                    }];
                    NSByteCountFormatter *byteFormatter = [[NSByteCountFormatter alloc]init];
                    byteFormatter.countStyle = NSByteCountFormatterCountStyleBinary;
                    for (NSNumber *time in sortedTime) {
                        NSString *size = [byteFormatter stringForObjectValue:sizeGroupedByTime[time]];
                        TUPrint(@"#%@ %@\n", time, size);
                    }
                } else if ([instrumentID isEqualToString:@"com.apple.xray.instrument-type.coreanimation"]) {
                    // Core Animation: print out all FPS data samples.
                    XRVideoCardRun *videoCardRun = (XRVideoCardRun *)run;
                    NSArrayController *arrayController = TUIvar(videoCardRun, _controller);
                    for (NSDictionary *sample in arrayController.arrangedObjects) {
                        NSNumber *fps = sample[@"FramesPerSecond"];
                        UInt64 timestamp = [sample[@"XRVideoCardRunTimeStamp"] integerValue] / USEC_PER_SEC;
                        TUPrint(@"#%@ %@ FPS\n", @(timestamp), fps);
                    }
                } else if ([instrumentID isEqualToString:@"com.apple.xray.instrument-type.networking"]) {
                    // Connections: print out all connections.
                    XRNetworkingInstrument *networkingInstrument = (XRNetworkingInstrument *)container;
                    [TUIvarCast(networkingInstrument, _topLevelContexts, XRContext * const *)[1] display]; // 3 contexts: Processes, Connections, Interfaces.
                    [networkingInstrument selectedRunRecomputeSummaries];
                    NSArrayController *arrayController = TUIvarCast(networkingInstrument, _controllersByTable, NSArrayController * const *)[1]; // The same index as for contexts.
                    XRNetworkAddressFormatter *localAddressFormatter = TUIvar(networkingInstrument, _localAddrFmtr);
                    XRNetworkAddressFormatter *remoteAddressFormatter = TUIvar(networkingInstrument, _remoteAddrFmtr);
                    NSByteCountFormatter *byteFormatter = [[NSByteCountFormatter alloc]init];
                    byteFormatter.countStyle = NSByteCountFormatterCountStyleBinary;
                    for (NSDictionary *entry in arrayController.arrangedObjects) {
                        NSString *localAddress = [localAddressFormatter stringForObjectValue:entry[@"localAddr"]];
                        NSString *remoteAddress = [remoteAddressFormatter stringForObjectValue:entry[@"remoteAddr"]];
                        NSString *inSize = [byteFormatter stringForObjectValue:entry[@"totalRxBytes"]];
                        NSString *outSize = [byteFormatter stringForObjectValue:entry[@"totalTxBytes"]];
                        TUPrint(@"%@ -> %@: %@ received, %@ sent\n", localAddress, remoteAddress, inSize, outSize);
                    }
                } else if ([instrumentID isEqualToString:@"com.apple.xray.power.mobile.energy"]) {
                    // Energy Usage Log: print out all energy usage level data.
                    XRStreamedPowerInstrument *powerInstrument = (XRStreamedPowerInstrument *)container;
                    [powerInstrument._permittedContexts[0] display]; // 2 contexts: Energy Consumption, Power Source Events
                    UInt64 columnCount = powerInstrument.definitionForCurrentDetailView.columnsInDataStreamCount;
                    UInt64 rowCount = powerInstrument.selectedEventTimeline.count;
                    XRPowerDetailController *powerDetail = TUIvar(powerInstrument, _detailController);
                    for (UInt64 row = 0; row < rowCount; row++) {
                        XRPowerDatum *datum = [powerDetail datumAtObjectIndex:row];
                        NSMutableString *string = [NSMutableString string];
                        [string appendFormat:@"%@-%@ s: ", @((double)datum.time.start / NSEC_PER_SEC), @((double)(datum.time.start + datum.time.length) / NSEC_PER_SEC)];
                        for (UInt64 column = 0; column < columnCount; column++) {
                            if (column > 0) {
                                [string appendString:@", "];
                            }
                            [string appendFormat:@"%@ %@", [datum labelForColumn:column], [datum objectValueForColumn:column]];
                        }
                        TUPrint(@"%@\n", string);
                    }
                }else if([instrumentID isEqualToString:@"com.apple.xray.instrument-type.vsync-event"]){
                    // todo: Displayed Surfaces: Print vsync time
                    TUPrint(@"For Displayed Surfaces\n");
                    //XRExtensionBasedInstrument *ebInstrument = (XRExtensionBasedInstrument *)container;
                    XRAnalysisCoreCallTreeViewController *callTreeView = TUIvar(container, _callTreeViewController);
                    XRMultiProcessBacktraceRepository *backtraceRepository = TUIvar(callTreeView, _backtraceRepository);
                    XRAnalysisCoreDetailNode *displayedNode = TUIvar(container, _displayedNode);
                    NSString *nodelabel = TUIvar(displayedNode, _label);
                    TUPrint(nodelabel);
                    XRAnalysisCoreDetailNode *nextNode = TUIvar(displayedNode, _nextSibling);
                    TUPrint(TUIvar(nextNode, _label));
                    XRContext *displayedContext = TUIvar(container, _displayedContext);
                    NSMutableDictionary *attributes = displayedContext.attributes;
                    for(id key in attributes){
                        id obj = [attributes objectForKey:key];
                        TUPrint(obj);
                    }
                    
                }else if([instrumentID isEqualToString:@"com.apple.xray.instrument-type.activity"]){
                    // Activity Monitor
                    TUPrint(@"To be implemented.\n");
                    XRAnalysisCoreDetailViewController * detail_controller = (XRAnalysisCoreDetailViewController *) container;
                    //XRAnalysisCoreTableViewController *activityTable = TUIvar(container, _tabularViewController);
                    //XRAnalysisCoreTableViewColumnList *cols = TUIvar(activityTable, _columns);
                    id<XRContextContainer> data_context = detail_controller.currentDataContext;
                    TUPrint(data_context);
                    
                    
                    
                }else {
                    TUPrint(@"Data processor has not been implemented for this type of instrument.\n");
                }
                
            }
            

            // Common routine to cleanup after done.
            [controller instrumentWillBecomeInvalid];
            
        }

        // Close the document safely.
        
        // PFTClosePlugins();
        [document close];
    }
    return 0;
}
