#import "LRLoginItemController.h"

#import <ServiceManagement/ServiceManagement.h>

@implementation LRLoginItemController

- (LRLoginItemState)state {
    switch (SMAppService.mainAppService.status) {
        case SMAppServiceStatusEnabled:
            return LRLoginItemStateEnabled;
        case SMAppServiceStatusRequiresApproval:
            return LRLoginItemStateRequiresApproval;
        case SMAppServiceStatusNotRegistered:
        case SMAppServiceStatusNotFound:
            return LRLoginItemStateDisabled;
    }
}

- (BOOL)setEnabled:(BOOL)enabled error:(NSError **)error {
    SMAppService *service = SMAppService.mainAppService;
    if (enabled && service.status == SMAppServiceStatusEnabled) { return YES; }
    if (!enabled && (service.status == SMAppServiceStatusNotRegistered ||
                     service.status == SMAppServiceStatusNotFound)) {
        return YES;
    }
    return enabled ? [service registerAndReturnError:error]
                   : [service unregisterAndReturnError:error];
}

- (void)openSystemSettings {
    [SMAppService openSystemSettingsLoginItems];
}

@end
