//
//  BMAlbumManager.m
//  BMImagePickerDemo
//
//  Created by jashion on 16/6/5.
//  Copyright © 2016年 BMu. All rights reserved.
//

#import "BMAlbumManager.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "Utils.h"

@interface BMAlbumManager ()

@property (nonatomic, strong) ALAssetsLibrary *assetsLibrary;
@property (nonatomic, strong) PHCachingImageManager *imageManager;

@end

@implementation BMAlbumManager

+ (BMAlbumManager *)sharedInstance {
    static dispatch_once_t pred = 0;
    __strong static id _shareObject = nil;
    
    dispatch_once(&pred, ^{
       _shareObject = [[self alloc] init];
    });
    return _shareObject;
}

#pragma mark - Custom Accessor

- (ALAssetsLibrary *)assetsLibrary {
    if (!_assetsLibrary) {
        _assetsLibrary = [[ALAssetsLibrary alloc] init];
        [ALAssetsLibrary disableSharedPhotoStreamsSupport];
    }
    return _assetsLibrary;
}

- (PHCachingImageManager *)imageManager {
    if (!_imageManager) {
        _imageManager = [[PHCachingImageManager alloc] init];
    }
    return _imageManager;
}

#pragma mark - Public Method

- (BOOL)authorizationStatusAuthoried {
    if (iOS8Later && ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized)) {
        return YES;
    } else if ([ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusAuthorized){
        return YES;
    } else {
        return NO;
    }
}

- (void)allAlbumsWithVideo: (BOOL)allowPickingVideo completion: (void(^)(NSArray<BMAlbumDataModel *> *albums, NSMutableArray *fetchResults, NSMutableArray *phAssetCollections))completion {
    NSMutableArray *albumsArray = @[].mutableCopy;
    NSMutableArray *fetchResultsArray = @[].mutableCopy;
    NSMutableArray *phAssetCollectionsArray = @[].mutableCopy;
    if (iOS8Later) {
        PHFetchOptions *option = [[PHFetchOptions alloc] init];
        if (!allowPickingVideo) {
            option.predicate = [NSPredicate predicateWithFormat: @"mediaType == %ld", PHAssetMediaTypeImage];
        }
        option.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey: @"creationDate" ascending: YES]];
        
        //适配iPad和iPhone里的所有图片
        PHFetchResult *allPhotos = [PHAsset fetchAssetsWithOptions: option];
        [albumsArray addObject: [self modelWithAssetResult: allPhotos name: @"所有照片"]];
        [fetchResultsArray addObject: allPhotos];
        [phAssetCollectionsArray addObject: allPhotos];
        
        PHFetchResult *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType: PHAssetCollectionTypeSmartAlbum subtype: PHAssetCollectionSubtypeAlbumRegular options: nil];
        for (PHAssetCollection *albumCollection in smartAlbums) {
            PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection: albumCollection options: option];
            if (fetchResult.count < 1) {
                continue;
            }

            [fetchResultsArray addObject: fetchResult];
            if ([albumCollection.localizedTitle isEqualToString: @"Recently Deleted"] || [albumCollection.localizedTitle isEqualToString: @"最近删除"]) {
                continue;
            }
            
            //iPhone里Selfies相册在smartAlbums里面，中文叫"自拍"
            if ([albumCollection.localizedTitle isEqualToString: @"Selfies"] || [albumCollection.localizedTitle isEqualToString: @"自拍"]) {
                [phAssetCollectionsArray insertObject: albumCollection atIndex: 1];
                [albumsArray insertObject:  [self modelWithAssetResult: fetchResult name: albumCollection.localizedTitle] atIndex: 1];
                continue;
            }
            
            //iPhone
            if ([albumCollection.localizedTitle isEqualToString: @"My Photo Stream"] || [albumCollection.localizedTitle isEqualToString: @"我的照片流"]) {
                [phAssetCollectionsArray insertObject: albumCollection atIndex: 1];
                [albumsArray insertObject:  [self modelWithAssetResult: fetchResult name: albumCollection.localizedTitle] atIndex: 1];
                continue;
            }
            
            //iPhone里smartAlbums的所有图片过滤掉，避免重复
            if ([albumCollection.localizedTitle isEqualToString: @"All photos"] || [albumCollection.localizedTitle isEqualToString: @"所有照片"]) {
                continue;
            }
            
            [phAssetCollectionsArray addObject: albumCollection];
            [albumsArray addObject: [self modelWithAssetResult: fetchResult name: albumCollection.localizedTitle]];
        }
        
        PHFetchResult *albums = [PHAssetCollection fetchAssetCollectionsWithType: PHAssetCollectionTypeAlbum subtype: PHAssetCollectionSubtypeAlbumRegular | PHAssetCollectionSubtypeAlbumMyPhotoStream options: nil];
        for (PHAssetCollection *albumCollection in albums) {
            PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection: albumCollection options: option];
            if (fetchResult.count < 1) {
                continue;
            }
            
            [fetchResultsArray addObject: fetchResult];
            //iPad里Selfies相册在userAlbums里面，中文叫"个人"
            if ([albumCollection.localizedTitle isEqualToString: @"Selfies"] || [albumCollection.localizedTitle isEqualToString: @"个人"]) {
                [phAssetCollectionsArray insertObject: albumCollection atIndex: 1];
                [albumsArray insertObject:  [self modelWithAssetResult: fetchResult name: albumCollection.localizedTitle] atIndex: 1];
                continue;
            }
            
            //iPad
            if ([albumCollection.localizedTitle isEqualToString: @"My Photo Stream"] || [albumCollection.localizedTitle isEqualToString: @"我的照片流"]) {
                [phAssetCollectionsArray insertObject: albumCollection atIndex: 1];
                [albumsArray insertObject:  [self modelWithAssetResult: fetchResult name: albumCollection.localizedTitle] atIndex: 1];
                continue;
            }

            [phAssetCollectionsArray addObject: albumCollection];
            [albumsArray addObject: [self modelWithAssetResult: fetchResult name: albumCollection.localizedTitle]];
        }

        if (completion) {
            completion(albumsArray, fetchResultsArray, phAssetCollectionsArray);
        }
    } else {
        [self.assetsLibrary enumerateGroupsWithTypes: ALAssetsGroupAll usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
            if (!allowPickingVideo) {
                ALAssetsFilter *onlyPhotosFilter = [ALAssetsFilter allPhotos];
                [group setAssetsFilter: onlyPhotosFilter];
            }
            
            if ([group numberOfAssets] > 0) {
                [albumsArray addObject: [self modelWithAssetResult: group name: [group valueForProperty: ALAssetsGroupPropertyName]]];
            } else {
                completion(albumsArray, nil, nil);
            }
        } failureBlock:^(NSError *error) {
            NSString *errorMessage = nil;
            switch ([error code]) {
                case ALAssetsLibraryAccessUserDeniedError:
                case ALAssetsLibraryAccessGloballyDeniedError:
                    errorMessage = @"The user has declined access to it.";
                    break;
                    
                default:
                    errorMessage = @"Reason unknow.";
                    break;
            }
            NSLog(@"%@", errorMessage);
        }];
    }
}

- (void)assetsFromFetchResult: (id)resultGroup allowPickingVideo: (BOOL)allowPickingVideo completion: (void(^)(NSArray<BMAlbumPhotoModel *> *assets))completion {
    NSMutableArray *results = @[].mutableCopy;
    if (iOS8Later) {
        PHFetchResult *fetchResult = (PHFetchResult *)resultGroup;
        [fetchResult enumerateObjectsUsingBlock:^(PHAsset *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            PHAsset *asset = (PHAsset *)obj;
            BMAlbumModelMediaType type = BMAlbumModelMediaTypePhoto;
            NSString *timeLength = @"";
            switch (asset.mediaType) {
                case PHAssetMediaTypeImage:
                {
                    if (iOS9_1Later && asset.mediaSubtypes == PHAssetMediaSubtypePhotoLive) {
                        type = BMAlbumModelMediaTypeLivePhoto;
                    } else {
                        type = BMAlbumModelMediaTypePhoto;
                    }
                    break;
                }
                    
                case PHAssetMediaTypeVideo:
                {
                    type = BMAlbumModelMediaTypeVideo;
                    timeLength = [self standardTimeFromDuration: asset.duration];
                    break;
                }
                    
                case PHAssetMediaTypeAudio:
                {
                    type = BMAlbumModelMediaTypeAudio;
                    break;
                }
                    
                case PHAssetMediaTypeUnknown:
                default:
                    break;
            }
            
            if (!allowPickingVideo && type == BMAlbumModelMediaTypeVideo) {
                return ;
            }
            
            [results addObject: [BMAlbumPhotoModel modelWithAsset: asset type: type timeLength: timeLength]];
        }];
        
        
        if (completion) {
            completion(results);
        }
    } else {
        ALAssetsGroup *group = (ALAssetsGroup *)resultGroup;
        if (!allowPickingVideo) {
            [group setAssetsFilter: [ALAssetsFilter allPhotos]];
        }
        
        [group enumerateAssetsUsingBlock:^(ALAsset *asset, NSUInteger index, BOOL *stop) {
            if (!asset && completion) {
                completion(results);
            }
            BMAlbumModelMediaType type = BMAlbumModelMediaTypePhoto;
            if (!allowPickingVideo) {
                [results addObject: [BMAlbumPhotoModel modelWithAsset: asset type: type]];
            }
            
            if ([asset valueForProperty: ALAssetPropertyType] == ALAssetTypeVideo) {
                type = BMAlbumModelMediaTypeVideo;
                NSString *timeLength = [self standardTimeFromDuration: [[asset valueForProperty: ALAssetPropertyDuration] doubleValue]];
                [results addObject: [BMAlbumPhotoModel modelWithAsset: asset type: type timeLength: timeLength]];
            }
        }];
    }
}

- (void)posterImageWithAlbum: (id)album width: (CGFloat)width completion: (didFinishPhotoHandle)completion {
    if ([album isKindOfClass: [PHFetchResult class]]) {
        PHFetchResult *result = (PHFetchResult *)album;
        [self imageWithAsset: [result lastObject] imageWith: width completion:^(UIImage *resultImage, NSDictionary *resultDict, BOOL degraded) {
            if (completion) {
                completion(resultImage);
            }
        }];
    } else if ([album isKindOfClass: [ALAssetsGroup class]]){
        ALAssetsGroup *group = (ALAssetsGroup *)album;
        CGImageRef posterImageRef = [group posterImage];
        UIImage *posterImage = [UIImage imageWithCGImage: posterImageRef];
        
        if (completion) {
            completion(posterImage);
        }
    }
}

- (void)thumbnailWithAsset: (id)asset width: (CGFloat)width completion: (didFinishPhotoHandle)completion {
    if ([asset isKindOfClass: [PHAsset class]]) {
        [self imageWithAsset: asset imageWith: width completion:^(UIImage *resultImage, NSDictionary *resultDict, BOOL degraded) {
            if (completion) {
                completion(resultImage);
            }
        }];
    } else if ([asset isKindOfClass: [ALAsset class]]) {
        ALAsset *photoAsset = (ALAsset *)asset;
        ALAssetRepresentation *assetRepresentation = [photoAsset defaultRepresentation];
        CGImageRef photoRef = photoAsset.thumbnail;
        UIImage *resultImage = [UIImage imageWithCGImage: photoRef
                                                   scale: [assetRepresentation scale]
                                             orientation: UIImageOrientationUp];
        if (completion) {
            completion(resultImage);
        }
    }
}

- (void)fullScreenImageWithAsset: (id)asset completion: (didFinishPhotoHandle)completion {
    [self photoWithAsset: asset width: [UIScreen mainScreen].bounds.size.width completion:^(UIImage *resultImage, NSDictionary *info, BOOL isDegraded) {
        completion(resultImage);
    }];
}

- (void)originalImageWithAsset: (id)asset completion: (didFinishPhotoInfoHandle)completion {
    if ([asset isKindOfClass: [PHAsset class]]) {
        PHImageRequestOptions *option = [[PHImageRequestOptions alloc] init];
        option.networkAccessAllowed = YES;
        option.progressHandler = ^(double progress, NSError *__nullable error, BOOL *stop, NSDictionary *__nullable info) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"originalImageProgress: %lf", progress);
            });
        };
        [[PHImageManager defaultManager] requestImageForAsset: asset
                                                   targetSize: PHImageManagerMaximumSize
                                                  contentMode: PHImageContentModeAspectFill
                                                      options: option
                                                resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
            BOOL downloadFinined = (![[info objectForKey: PHImageCancelledKey] boolValue] && ![info objectForKey: PHImageErrorKey]);
            BOOL degraded = [[info objectForKey: PHImageResultIsDegradedKey] boolValue];
            if (downloadFinined && result && !degraded) {
                if (completion) {
                    completion(result, info);
                }
            }
        }];
    } else if ([asset isKindOfClass: [ALAsset class]]) {
        ALAsset *photoAsset = (ALAsset *)asset;
        ALAssetRepresentation *assetRepresentation = [photoAsset defaultRepresentation];
        
        //放在异步线程防止阻塞主线程
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            CGImageRef photoRef = [assetRepresentation fullResolutionImage];
            
            //主要针对iOS6~iOS7情况(注意：编辑过的图片不一定能获取到adjustmenXMP)，iOS8+开始使用Photos的框架
            NSString *adjustmentXMP = assetRepresentation.metadata[@"AdjustmentXMP"];
            if (adjustmentXMP) {
                NSData *adjustmentXMPData = [adjustmentXMP dataUsingEncoding: NSUTF8StringEncoding];
                CIImage *ciImage = [CIImage imageWithCGImage: photoRef];
                NSError *error = nil;
                NSArray *filterArray = [CIFilter filterArrayFromSerializedXMP: adjustmentXMPData
                                                             inputImageExtent: ciImage.extent
                                                                        error: &error];
                if (filterArray && !error) {
                    CIContext *ciContext = [CIContext contextWithOptions: nil];
                    for (CIFilter *filter in filterArray) {
                        [filter setValue: ciImage forKey: kCIInputImageKey];
                        ciImage = [filter outputImage];
                    }
                    photoRef = [ciContext createCGImage: ciImage fromRect: [ciImage extent]];
                }
            }
            
            UIImage *originalImage = [UIImage imageWithCGImage: photoRef
                                                         scale: [assetRepresentation scale]
                                                   orientation: (UIImageOrientation)[assetRepresentation orientation]];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) {
                        completion(originalImage, nil);
                     }
                });
        });
    }
}

- (void)photoWithAsset: (id)asset width: (CGFloat)width completion: (didFinishPhotoInfoWithDegradHandle)completion {
    if ([asset isKindOfClass: [PHAsset class]]) {
        [self imageWithAsset: asset imageWith: width completion:^(UIImage *resultImage, NSDictionary *resultDict, BOOL degraded) {
            if (completion) {
                completion(resultImage, resultDict, degraded);
            }
        }];
    } else if ([asset isKindOfClass: [ALAsset class]]) {
        ALAsset *photoAsset = (ALAsset *)asset;
        ALAssetRepresentation *assetRepresentation = [photoAsset defaultRepresentation];
        CGImageRef photoRef = assetRepresentation.fullScreenImage;
        UIImage *resultImage = [UIImage imageWithCGImage: photoRef
                                                   scale: [assetRepresentation scale]
                                             orientation: UIImageOrientationUp];
        if (completion) {
            completion(resultImage, nil, nil);
        }
    }
}

- (void)livePhotoWithAsset: (id)asset completion: (didFinishLivePhotoInfoWithDegradHandle)completion {
    if (!iOS9_1Later) {
        return;
    }
    
    if (![asset isKindOfClass: [PHAsset class]]) {
        return;
    }
    
    PHAsset *phAsset = (PHAsset *)asset;
    if (phAsset.mediaSubtypes != PHAssetMediaSubtypePhotoLive) {
        return;
    }
    
    PHLivePhotoRequestOptions *livePhotoOptions = [[PHLivePhotoRequestOptions alloc] init];
    livePhotoOptions.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    livePhotoOptions.networkAccessAllowed = YES;
    livePhotoOptions.progressHandler = ^(double progress, NSError *error, BOOL *stop, NSDictionary *info){
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"livePhotoProgress: %lf", progress);
        });
    };
    
    [[PHImageManager defaultManager] requestLivePhotoForAsset: phAsset targetSize: [UIScreen mainScreen].bounds.size contentMode: PHImageContentModeAspectFit options: livePhotoOptions resultHandler:^(PHLivePhoto * _Nullable livePhoto, NSDictionary * _Nullable info) {
        if (!livePhoto) {
            return ;
        }
        
        if (completion) {
            completion(livePhoto, info);
        }
    }];
}

- (void)fullScreenImageWithAsset: (id)asset imageCompletion: (didFinishPhotoInfoHandle)imageCompletion gifCompletion: (didFinishGIFInfoWithDegradHandle)gifCompletion {
    [self photoWithAsset: asset width: [UIScreen mainScreen].bounds.size.width completion:^(UIImage *resultImage, NSDictionary *info, BOOL isDegraded) {
        if (imageCompletion) {
            imageCompletion(resultImage, info);
        }
    }];
    if ([asset isKindOfClass: [PHAsset class]]) {
        NSArray *array = [PHAssetResource assetResourcesForAsset: asset];
        __block BOOL isGif;
        [array enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            PHAssetResource *resource = obj;
            if ([resource.uniformTypeIdentifier isEqualToString: (__bridge NSString*)kUTTypeGIF]) {
                isGif = YES;
                *stop = YES;
            }
        }];
        if (!isGif) {
            return;
        }
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            PHImageRequestOptions *option = [[PHImageRequestOptions alloc] init];
            option.networkAccessAllowed = YES;
            [[PHImageManager defaultManager] requestImageDataForAsset: asset options: option resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
                BOOL downloadFinined = (![[info objectForKey: PHImageCancelledKey] boolValue] && ![info objectForKey: PHImageErrorKey]);
                BOOL degraded = [[info objectForKey: PHImageResultIsDegradedKey] boolValue];
                if (downloadFinined && !degraded && imageData.length > 0) {
                    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
                    size_t count = CGImageSourceGetCount(imageSource);
                    NSMutableArray *images = @[].mutableCopy;
                    for (int index = 0; index < count; index++) {
                        CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, index, NULL);
                        UIImage *image = [UIImage imageWithCGImage: imageRef];
                        CGImageRelease(imageRef);
                        [images addObject: image];
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (gifCompletion) {
                            gifCompletion([images mutableCopy], info);
                        }
                    });
                }
            }];
        });
    } else if ([asset isKindOfClass: [ALAsset class]]) {
        ALAsset *alAsset = (ALAsset *)asset;
        ALAssetRepresentation *assetRepresentation = [alAsset representationForUTI: (__bridge NSString*)kUTTypeGIF];
        if (assetRepresentation) {
            long long size = assetRepresentation.size;
            uint8_t *imageBuffer = malloc(size);
            NSError *error;
            NSUInteger bufferSize = [assetRepresentation getBytes: imageBuffer fromOffset: 0.0 length: size error: &error];
            NSData *imageData = [NSData dataWithBytesNoCopy: imageBuffer length: bufferSize freeWhenDone: YES];
            CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
            size_t count = CGImageSourceGetCount(imageSource);
            NSMutableArray *images = @[].mutableCopy;
            for (int index = 0; index < count; index++) {
                CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, index, NULL);
                UIImage *image = [UIImage imageWithCGImage: imageRef];
                CGImageRelease(imageRef);
                [images addObject: image];
            }
            if (gifCompletion) {
                gifCompletion(images, nil);
            }
        }
    }
}

- (void)getVideoWithAsset: (id)asset completion: (void(^)(AVPlayerItem *playerItem, NSDictionary *info))completion {
    if ([asset isKindOfClass: [PHAsset class]]) {
        PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
        options.networkAccessAllowed = YES;
        options.progressHandler = ^(double progress, NSError *__nullable error, BOOL *stop, NSDictionary *__nullable info) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"videoProgress: %lf", progress);
            });
        };
        [[PHImageManager defaultManager] requestPlayerItemForVideo: asset options: options resultHandler:^(AVPlayerItem * _Nullable playerItem, NSDictionary * _Nullable info) {
            if (playerItem && completion) {
                completion(playerItem, info);
            }
        }];
    } else if ([asset isKindOfClass: [ALAsset class]]){
        ALAsset *alAsset = (ALAsset *)asset;
        ALAssetRepresentation *defaultRepresentation = [alAsset defaultRepresentation];
        NSString *uti = [defaultRepresentation UTI];
        NSURL *videoURL = [[alAsset valueForProperty: ALAssetPropertyURLs] valueForKey: uti];
        AVPlayerItem *playerItem = [[AVPlayerItem alloc] initWithURL: videoURL];
        if (playerItem && completion) {
            completion(playerItem, nil);
        }
    }
}

- (void)createAlbumWithTitle:(NSString *)title completion: (void(^)(id assetGroup))completion {
    if (iOS8Later) {
        __block NSString *localIndentifier;
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            localIndentifier = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle: title].placeholderForCreatedAssetCollection.localIdentifier;
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            if (!success) {
                NSLog(@"Error: %@", [error localizedDescription]);
            }
            
            if (success && completion) {
                completion(localIndentifier);
            }
        }];
    } else {
        [self.assetsLibrary addAssetsGroupAlbumWithName: title resultBlock:^(ALAssetsGroup *group) {
            if (group && completion) {
                completion(group);
            }
        } failureBlock:^(NSError *error) {
            NSLog(@"Error: %@", [error localizedDescription]);
        }];
    }
}

- (void)saveImageToAlbum: (id)album image: (UIImage *)image completion: (void(^)(BOOL success))completion {
    if (!album && !image) {
        return;
    }
    
    //ALAssetsGroup不能直接存储图片，只能添加ALAsset
    //存储图片步骤：
    //1.存储图片到本地相机相册，成功后获取一个AssetUrl
    //2.通过AssetUrl获得一个Asset
    //3.将Asset添加到相应的AssetGroup里面
    //注意：删除本地相册的相机照片，相应的相册里面的照片也会被删除，因为它们是同一个Asset
    if ([album isKindOfClass: [ALAssetsGroup class]]) {
        ALAssetsGroup *assetGroup = (ALAssetsGroup *)album;
        
        __weak typeof(self) weakSelf = self;
        [self assetUrlWithImage: image completion:^(NSURL *assetURL) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf assetWithUrl: assetURL completion:^(ALAsset *asset) {
                [assetGroup addAsset: asset];
                if (completion) {
                    completion(YES);
                }
            }];
        }];
        return;
    }
    
    //Photos框架可以直接存储照片
    if ([album isKindOfClass: [PHAssetCollection class]]) {
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetChangeRequest *phAssetRequest = [PHAssetChangeRequest creationRequestForAssetFromImage: image];
            PHAssetCollectionChangeRequest *phAssetCollectionRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection: album];
            [phAssetCollectionRequest addAssets: @[[phAssetRequest placeholderForCreatedAsset ]]];
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            if (!success) {
                NSLog(@"Error: %@", error);
            }
            if (completion) {
                completion(success);
            }
        }];
        return;
    }
    
    //在Photos框架里的每一相册都会有一个PHObjectPlaceholder，包含一个本地的localIdentifier
    if ([album isKindOfClass: [NSString class]]) {
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            NSString *localIdentifier = (NSString *)album;
            PHFetchResult *result = [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers: @[localIdentifier] options: nil];
            PHAssetCollectionChangeRequest *phAssetCollectionRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection: (PHAssetCollection *)[result objectAtIndex: 0]];
            PHAssetChangeRequest *phAssetRequest = [PHAssetChangeRequest creationRequestForAssetFromImage: image];
            [phAssetCollectionRequest addAssets: @[[phAssetRequest placeholderForCreatedAsset]]];
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            if (completion) {
                completion(success);
            }
        }];
        return;
    }
    
    //没有指定相册就直接存储在本地默认相册
    if (iOS8Later) {
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromImage: image];
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            if (completion) {
                completion(success);
            }
        }];
    } else {
        [self.assetsLibrary writeImageToSavedPhotosAlbum: image.CGImage orientation: (ALAssetOrientation)[image imageOrientation] completionBlock:^(NSURL *assetURL, NSError *error) {
            if (assetURL && completion) {
                completion(YES);
            }
        }];
    }
}

#pragma mark - Private Method

- (void)imageWithAsset: (id)asset imageWith: (CGFloat)imageWidth completion: (void(^)(UIImage *resultImage, NSDictionary *resultDict, BOOL degraded))completion {
    if (imageWidth > [UIScreen mainScreen].bounds.size.width) {
        imageWidth = [UIScreen mainScreen].bounds.size.width;
    }
    
    if ([asset isKindOfClass: [PHAsset class]]) {
        PHAsset *phAsset = (PHAsset *)asset;
        CGFloat aspectRatio = phAsset.pixelWidth / (CGFloat)phAsset.pixelHeight;
        CGFloat mutiple = [UIScreen mainScreen].scale;
        CGFloat resultImageWidth = imageWidth * mutiple;
        CGFloat resultImageHeight = resultImageWidth / aspectRatio;
        
        [[PHImageManager defaultManager] requestImageForAsset: phAsset
                                                   targetSize: CGSizeMake(resultImageWidth, resultImageHeight)
                                                  contentMode: PHImageContentModeAspectFill
                                                      options: nil
                                                resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
            BOOL downloadFinished = (![[info objectForKey: PHImageCancelledKey] boolValue] && ![info objectForKey: PHImageErrorKey]);
            if (downloadFinished && result) {
                if (completion) {
                    completion(result, info, [[info objectForKey: PHImageResultIsDegradedKey] boolValue]);
                }
            }
            
            // Download image from iCloud
            if ([[info objectForKey: PHImageResultIsInCloudKey] boolValue] && !result) {
                 PHImageRequestOptions *option = [[PHImageRequestOptions alloc] init];
                 option.networkAccessAllowed = YES;
                 [[PHImageManager defaultManager] requestImageDataForAsset: asset
                                                     options: option
                                               resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
                    UIImage *resultImage = [UIImage imageWithData: imageData scale: [UIScreen mainScreen].scale];
                    if (resultImage && completion) {
                        completion(resultImage, info, [[info objectForKey: PHImageResultIsDegradedKey] boolValue]);
                    }
                 }];
            }
        }];
    } else if ([asset isKindOfClass: [ALAsset class]]){
        ALAsset *resultAsset = (ALAsset *)asset;
        if (imageWidth == [UIScreen mainScreen].bounds.size.width) {
            ALAssetRepresentation *represent = [resultAsset defaultRepresentation];
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
               CGImageRef imageRef = [represent fullScreenImage];
               UIImage *resultImage = [UIImage imageWithCGImage: imageRef
                                                          scale: represent.scale
                                                    orientation: (UIImageOrientation)represent.orientation];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) {
                        completion(resultImage, nil, NO);
                    }
                });
            });
        } else {
            CGImageRef imageRef = resultAsset.aspectRatioThumbnail;
            UIImage *resultImage = [UIImage imageWithCGImage: imageRef
                                                       scale: [UIScreen mainScreen].scale
                                                 orientation: UIImageOrientationUp];
            if (completion) {
                completion(resultImage, nil, YES);
            }
        }
    }
}

- (void)assetUrlWithImage: (UIImage *)image completion: (void(^)(NSURL *assetURL))completion {
    [self.assetsLibrary writeImageToSavedPhotosAlbum: image.CGImage orientation: (ALAssetOrientation)[image imageOrientation] completionBlock:^(NSURL *assetURL, NSError *error) {
        if (assetURL && completion) {
            completion(assetURL);
        }
    }];
}

- (void)assetWithUrl: (NSURL *)url completion: (void(^)(ALAsset *asset))completion {
    [self.assetsLibrary assetForURL: url resultBlock:^(ALAsset *asset) {
        if (completion) {
            completion(asset);
        }
    } failureBlock:^(NSError *error) {
        NSLog(@"Error: %@", [error localizedDescription]);
    }];
}

- (BMAlbumDataModel *)modelWithAssetResult: (id)assetResult name: (NSString *)albumName {
    BMAlbumDataModel *model = [BMAlbumDataModel new];
    model.assetResult = assetResult;
    model.albumName = albumName;
    if ([assetResult isKindOfClass: [PHFetchResult class]]) {
        PHFetchResult *fetchResult = (PHFetchResult *)assetResult;
        model.imagesCount = fetchResult.count;
    } else if ([assetResult isKindOfClass: [ALAssetsGroup class]]) {
        ALAssetsGroup *assetsGroup = (ALAssetsGroup *)assetResult;
        model.imagesCount = [assetsGroup numberOfAssets];
    }
    return model;
}

- (NSString *)standardTimeFromDuration: (NSTimeInterval)duration {
    NSString *newTime = @"0:00";
    NSInteger newDuration = round(duration);
    NSInteger seconds = newDuration % 60;
    NSInteger minutes = newDuration / 60 % 60;
    NSInteger hours = newDuration / 3600;
    NSString *secondStr;
    NSString *minuteStr;
    if (seconds < 10) {
        secondStr = [NSString stringWithFormat: @"0%ld", seconds];
    } else {
        secondStr = [NSString stringWithFormat: @"%ld", seconds];
    }
    if (hours > 0) {
        if (minutes < 10) {
            minuteStr = [NSString stringWithFormat: @"0%ld", minutes];
        } else {
            minuteStr = [NSString stringWithFormat: @"%ld", minutes];
        }
    } else {
        minuteStr = [NSString stringWithFormat: @"%ld", minutes];
    }
    NSString *hourStr = [NSString stringWithFormat: @"%ld", hours];
    if (hours > 0) {
        newTime = [NSString stringWithFormat: @"%@:%@:%@", hourStr, minuteStr, secondStr];
    } else {
        newTime = [NSString stringWithFormat: @"%@:%@", minuteStr, secondStr];
    }
    return newTime;
}

+ (void)collectionMediaTypeWithAsset: (id)asset completion: (void(^)(BMAlbumModelMediaType type))completion{
    __block BMAlbumModelMediaType type = BMAlbumModelMediaTypePhoto;
    if (iOS8Later) {
        PHFetchResult *fetchResult = (PHFetchResult *)asset;
        PHAsset *phAsset = [fetchResult objectAtIndex: 0];
        if (phAsset.mediaType == PHAssetMediaTypeVideo) {
            type = BMAlbumModelMediaTypeVideo;
        } else if (phAsset.mediaType == PHAssetMediaTypeAudio) {
            type = BMAlbumModelMediaTypeAudio;
        } else if (phAsset.mediaType == PHAssetMediaTypeImage && phAsset.mediaSubtypes == PHAssetMediaSubtypePhotoLive){
            type = BMAlbumModelMediaTypeLivePhoto;
        }
    } else {
        ALAssetsGroup *assetGroup = (ALAssetsGroup *)asset;
        [assetGroup enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
            if (index == 0) {
                if ([result valueForProperty: ALAssetPropertyType] == ALAssetTypeVideo) {
                    type = BMAlbumModelMediaTypeVideo;
                }
                *stop = YES;
            }
        }];
    }
    
    if (completion) {
        completion(type);
    }
}

@end
