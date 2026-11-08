#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT Class _Nullable WHPeripheralManagerClass(void);
FOUNDATION_EXPORT id _Nullable WHCreatePeripheralManager(id _Nullable delegate, dispatch_queue_t _Nullable queue, NSError * _Nullable * _Nullable outError);

FOUNDATION_EXPORT id _Nullable WHCreateUUID(NSString *uuidString);
FOUNDATION_EXPORT id _Nullable WHCreateMutableService(NSString *uuidString, BOOL primary);
FOUNDATION_EXPORT id _Nullable WHCreateMutableCharacteristic(NSString *uuidString,
                                                             NSUInteger properties,
                                                             NSData * _Nullable value,
                                                             NSUInteger permissions);
FOUNDATION_EXPORT id _Nullable WHCreateMutableDescriptor(NSString *uuidString, id _Nullable value);
FOUNDATION_EXPORT void WHSetCharacteristics(id service, NSArray *characteristics);
FOUNDATION_EXPORT void WHSetDescriptors(id characteristic, NSArray *descriptors);

FOUNDATION_EXPORT void WHRemoveAllServices(id peripheral);
FOUNDATION_EXPORT void WHAddService(id peripheral, id service);
FOUNDATION_EXPORT void WHStartAdvertising(id peripheral, NSDictionary *advertisement);
FOUNDATION_EXPORT void WHStopAdvertising(id peripheral);
FOUNDATION_EXPORT NSInteger WHPeripheralState(id peripheral);
FOUNDATION_EXPORT BOOL WHIsAdvertising(id peripheral);

/// Raw advertisement keys (may be missing from watchOS Swift overlays).
FOUNDATION_EXPORT NSString * const WHAdvertisementLocalNameKey;
FOUNDATION_EXPORT NSString * const WHAdvertisementServiceUUIDsKey;
FOUNDATION_EXPORT NSString * const WHAdvertisementAppearanceKey;

NS_ASSUME_NONNULL_END
