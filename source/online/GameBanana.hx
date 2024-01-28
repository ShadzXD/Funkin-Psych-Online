package online;

import openfl.utils.ByteArray;
import openfl.display.PNGEncoderOptions;
import openfl.geom.Rectangle;
import openfl.display.BitmapData;
import lime.system.System;
import states.ModsMenuState.ModMetadata;
import sys.thread.Thread;
import online.states.OpenURL;
import backend.Song;
import haxe.crypto.Md5;
import haxe.zip.Entry;
import sys.FileSystem;
import sys.io.File;
import haxe.zip.Reader;
import haxe.Http;
import haxe.Json;

typedef GBMod = {
	var _id:String;
	var name:String;
	var description:String;
	var downloads:Dynamic;
	var pageDownload:String;
	var game:String;
	var trashed:Bool;
	var withheld:Bool;
	var rootCategory:String;
}

typedef GBSub = {
	var _sName:String;
	var _sProfileUrl:String;
	var _aPreviewMedia:GBPrevMedia;
	var _aRootCategory:GBCategory;
	var _sVersion:String;
	var _nLikeCount:Null<Int>; // "null cant be used as int!!!" then why does this return null instead of 0
}

typedef GBPrevMedia = {
	var _aImages:Array<GBImage>;
}

typedef GBImage = {
	var _sBaseUrl:String;
	var _sFile:String;
	var _sFile220:String; //only on the first
	var _wFile220:Int;
	var _hFile220:Int;
	var _sFile100:String;
}

typedef GBCategory = {
	var _sName:String;
	var _sIconUrl:String;
}

typedef DownloadProp = {
	var _sFile:String;
	var _sAnalysisState:String;
	var _sDownloadUrl:String;
	var _bContainsExe:Bool;
}

class GameBanana {
	public static function searchMods(?search:String, page:Int, response:(mods:Array<GBSub>, err:Dynamic) -> Void) {
		Thread.create(() -> {
			var http = new Http(
			'https://gamebanana.com/apiv11/Game/8694/Subfeed?_nPage=${page}&_sSort=default&_csvModelInclusions=Mod' + (search != null ? '&_sName=$search' : '')
			);

			http.onData = function(data:String) {
				Waiter.put(() -> {
					var json:Dynamic = Json.parse(data);
					response(cast(json._aRecords), json._sErrorCode != null ? json._sErrorCode : null);
				});
			}

			http.onError = function(error) {
				Waiter.put(() -> {
					response(null, error);
				});
			}

			http.request();
		});
	}

	public static function getMod(id:String, response:(mod:GBMod, err:Dynamic)->Void) {
		Thread.create(() -> {
			var http = new Http(
			"https://api.gamebanana.com/Core/Item/Data?itemtype=Mod&itemid=" + id + 
			"&fields=name,description,Files().aFiles(),Url().sDownloadUrl(),Game().name,Trash().bIsTrashed(),Withhold().bIsWithheld(),RootCategory().name"
			);

			http.onData = function(data:String) {
				var arr:Array<Dynamic> = Json.parse(data);
				
				response({
					_id: id,
					name: arr[0],
					description: arr[1],
					downloads: arr[2],
					pageDownload: arr[3],
					game: arr[4],
					trashed: arr[5],
					withheld: arr[6],
					rootCategory: arr[7]
				}, null);
			}

			http.onError = function(error) {
				response(null, error);
			}

			http.request();
		});
    }

	public static function downloadMod(mod:GBMod, ?onSuccess:String->Void) {
        if (mod.trashed || mod.withheld) {
			Alert.alert("Failed to download!", "That mod is deleted!");
			return;
        }

        var daModUrl:String = null;
		var dlFileName:String = null;
		for (_download in Reflect.fields(mod.downloads)) {
			var download = Reflect.field(mod.downloads, _download);
			if (FileUtils.isArchiveSupported(download._sFile) && download._bContainsExe == false && download._sClamAvResult == "clean") {
				daModUrl = download._sDownloadUrl;
				dlFileName = download._sFile;
                break;
            }
        }

		if (daModUrl == null) {
			Alert.alert("Failed to download!", "Unsupported file archive type!\n(Only ZIP, TAR, TGZ archives are supported!)");
			OpenURL.open(mod.pageDownload, "The following mod needs to be installed from this source", null, null, true);
			return;
		}

		OnlineMods.startDownloadMod(dlFileName, daModUrl, mod, onSuccess);
    }
}