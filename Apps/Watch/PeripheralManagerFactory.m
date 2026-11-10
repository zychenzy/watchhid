#import "PeripheralManagerFactory.h"
#import <objc/runtime.h>
#import <objc/message.h>

NSString * const WHAdvertisementLocalNameKey = @"kCBAdvDataLocalName";
NSString * const WHAdvertisementServiceUUIDsKey = @"kCBAdvDataServiceUUIDs";
NSString * const WHAdvertisementAppearanceKey = @"kCBAdvDataAppearance";

static id WHAllocInit(NSString *className, SEL sel, void (^ _Nullable fill)(id obj, SEL s)) {
    Class cls = NSClassFromString(className);
    if (!cls) return nil;
    id obj = ((id (*)(Class, SEL))objc_msgSend)(cls, NSSelectorFromString(@"alloc"));
    if (!obj) return nil;
    if (fill) {
        fill(obj, sel);
        return obj;
    }
    return ((id (*)(id, SEL))objc_msgSend)(obj, NSSelectorFromString(@"init"));
}

Class WHPeripheralManagerClass(void) {
    return NSClassFromString(@"CBPeripheralManager");
}

id WHCreatePeripheralManager(id delegate, dispatch_queue_t queue, NSError **outError) {
    Class cls = WHPeripheralManagerClass();
    if (!cls) {
        if (outError) {
            *outError = [NSError errorWithDomain:@"WatchHID" code:1 userInfo:@{NSLocalizedDescriptionKey: @"CBPeripheralManager class missing"}];
        }
        return nil;
    }
    id allocated = ((id (*)(Class, SEL))objc_msgSend)(cls, NSSelectorFromString(@"alloc"));
    SEL initSel = NSSelectorFromString(@"initWithDelegate:queue:");
    if ([allocated respondsToSelector:initSel]) {
        return ((id (*)(id, SEL, id, dispatch_queue_t))objc_msgSend)(allocated, initSel, delegate, queue);
    }
    SEL initOpts = NSSelectorFromString(@"initWithDelegate:queue:options:");
    if ([allocated respondsToSelector:initOpts]) {
        return ((id (*)(id, SEL, id, dispatch_queue_t, id))objc_msgSend)(allocated, initOpts, delegate, queue, nil);
    }
    SEL plainInit = NSSelectorFromString(@"init");
    id managed = ((id (*)(id, SEL))objc_msgSend)(allocated, plainInit);
    SEL setDelegate = NSSelectorFromString(@"setDelegate:");
    if (managed && delegate && [managed respondsToSelector:setDelegate]) {
        ((void (*)(id, SEL, id))objc_msgSend)(managed, setDelegate, delegate);
    }
    if (!managed && outError) {
        *outError = [NSError errorWithDomain:@"WatchHID" code:6 userInfo:@{NSLocalizedDescriptionKey: @"No usable CBPeripheralManager initializer"}];
    }
    return managed;
}

id WHCreateUUID(NSString *uuidString) {
    Class cls = NSClassFromString(@"CBUUID");
    if (!cls) return nil;
    SEL sel = NSSelectorFromString(@"UUIDWithString:");
    return ((id (*)(Class, SEL, id))objc_msgSend)(cls, sel, uuidString);
}

id WHCreateMutableService(NSString *uuidString, BOOL primary) {
    id uuid = WHCreateUUID(uuidString);
    if (!uuid) return nil;
    Class cls = NSClassFromString(@"CBMutableService");
    if (!cls) return nil;
    id obj = ((id (*)(Class, SEL))objc_msgSend)(cls, NSSelectorFromString(@"alloc"));
    SEL sel = NSSelectorFromString(@"initWithType:primary:");
    if (![obj respondsToSelector:sel]) return nil;
    return ((id (*)(id, SEL, id, BOOL))objc_msgSend)(obj, sel, uuid, primary);
}

id WHCreateMutableCharacteristic(NSString *uuidString, NSUInteger properties, NSData *value, NSUInteger permissions) {
    id uuid = WHCreateUUID(uuidString);
    if (!uuid) return nil;
    Class cls = NSClassFromString(@"CBMutableCharacteristic");
    if (!cls) return nil;
    id obj = ((id (*)(Class, SEL))objc_msgSend)(cls, NSSelectorFromString(@"alloc"));
    SEL sel = NSSelectorFromString(@"initWithType:properties:value:permissions:");
    if (![obj respondsToSelector:sel]) return nil;
    return ((id (*)(id, SEL, id, NSUInteger, id, NSUInteger))objc_msgSend)(obj, sel, uuid, properties, value, permissions);
}

id WHCreateMutableDescriptor(NSString *uuidString, id value) {
    id uuid = WHCreateUUID(uuidString);
    if (!uuid) return nil;
    Class cls = NSClassFromString(@"CBMutableDescriptor");
    if (!cls) return nil;
    id obj = ((id (*)(Class, SEL))objc_msgSend)(cls, NSSelectorFromString(@"alloc"));
    SEL sel = NSSelectorFromString(@"initWithType:value:");
    if (![obj respondsToSelector:sel]) return nil;
    return ((id (*)(id, SEL, id, id))objc_msgSend)(obj, sel, uuid, value);
}

void WHSetCharacteristics(id service, NSArray *characteristics) {
    SEL sel = NSSelectorFromString(@"setCharacteristics:");
    if ([service respondsToSelector:sel]) {
        ((void (*)(id, SEL, id))objc_msgSend)(service, sel, characteristics);
    }
}

void WHSetDescriptors(id characteristic, NSArray *descriptors) {
    SEL sel = NSSelectorFromString(@"setDescriptors:");
    if ([characteristic respondsToSelector:sel]) {
        ((void (*)(id, SEL, id))objc_msgSend)(characteristic, sel, descriptors);
    }
}

void WHRemoveAllServices(id peripheral) {
    SEL sel = NSSelectorFromString(@"removeAllServices");
    if ([peripheral respondsToSelector:sel]) {
        ((void (*)(id, SEL))objc_msgSend)(peripheral, sel);
    }
}

void WHAddService(id peripheral, id service) {
    SEL sel = NSSelectorFromString(@"addService:");
    if ([peripheral respondsToSelector:sel]) {
        ((void (*)(id, SEL, id))objc_msgSend)(peripheral, sel, service);
    }
}

void WHStartAdvertising(id peripheral, NSDictionary *advertisement) {
    SEL sel = NSSelectorFromString(@"startAdvertising:");
    if ([peripheral respondsToSelector:sel]) {
        ((void (*)(id, SEL, id))objc_msgSend)(peripheral, sel, advertisement);
    }
}

void WHStopAdvertising(id peripheral) {
    SEL sel = NSSelectorFromString(@"stopAdvertising");
    if ([peripheral respondsToSelector:sel]) {
        ((void (*)(id, SEL))objc_msgSend)(peripheral, sel);
    }
}

NSInteger WHPeripheralState(id peripheral) {
    if ([peripheral respondsToSelector:NSSelectorFromString(@"state")]) {
        NSNumber *n = [peripheral valueForKey:@"state"];
        return n.integerValue;
    }
    return -1;
}

BOOL WHIsAdvertising(id peripheral) {
    if ([peripheral respondsToSelector:NSSelectorFromString(@"isAdvertising")]) {
        NSNumber *n = [peripheral valueForKey:@"isAdvertising"];
        return n.boolValue;
    }
    return NO;
}

NSArray<NSString *> *WHRuntimeClassNames(void) {
    unsigned int count = 0;
    Class __unsafe_unretained *classes = objc_copyClassList(&count);
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (unsigned int i = 0; i < count; i++) {
        const char *name = class_getName(classes[i]);
        if (name) [names addObject:[NSString stringWithUTF8String:name]];
    }
    free(classes);
    return names;
}

NSString *WHAddServiceChecked(id peripheral, id service) {
    @try { WHAddService(peripheral, service); return nil; }
    @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
}
NSString *WHStartAdvertisingChecked(id peripheral, NSDictionary *advertisement) {
    @try { WHStartAdvertising(peripheral, advertisement); return nil; }
    @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
}

NSArray<NSString *> *WHRuntimeClassDetails(NSArray<NSString *> *names) {
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    for (NSString *name in names) {
        Class __unsafe_unretained cls = objc_lookUpClass(name.UTF8String);
        if (!cls) { [out addObject:[name stringByAppendingString:@": absent"]]; continue; }
        const char *image = class_getImageName(cls);
        [out addObject:[NSString stringWithFormat:@"CLASS %@ image=%s", name, image ?: "unknown"]];
        unsigned int count = 0;
        Method *methods = class_copyMethodList(cls, &count);
        for (unsigned int i = 0; i < count; i++) {
            [out addObject:[NSString stringWithFormat:@"METHOD %@ %s types=%s", name,
                sel_getName(method_getName(methods[i])), method_getTypeEncoding(methods[i])]];
        }
        free(methods);
    }
    return out;
}

void WHRespondToRequest(id peripheral, id request, NSInteger result) {
    ((void (*)(id, SEL, id, NSInteger))objc_msgSend)(peripheral, NSSelectorFromString(@"respondToRequest:withResult:"), request, result);
}
BOOL WHUpdateReportToCentrals(id peripheral, NSData *data, id characteristic, NSArray * _Nullable centrals) {
    if (peripheral == nil || data == nil || characteristic == nil) {
        return NO;
    }
    SEL sel = NSSelectorFromString(@"updateValue:forCharacteristic:onSubscribedCentrals:");
    if (![peripheral respondsToSelector:sel]) {
        return NO;
    }
    return ((BOOL (*)(id, SEL, id, id, id))objc_msgSend)(peripheral, sel, data, characteristic, centrals);
}

BOOL WHUpdateReport(id peripheral, NSData *data, id characteristic) {
    return WHUpdateReportToCentrals(peripheral, data, characteristic, nil);
}
