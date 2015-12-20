
function BBAsyncSoundLoaderThread()
{
	this._running=false;
}
  
if (CFG_HTML5_WEBAUDIO_ENABLED == "1" && (window.AudioContext || window.webkitAudioContext))
{
	BBAsyncSoundLoaderThread.prototype.Start=function()
	{
		this._sample=null;
		if( !this._device.okay ) return;
		
		var thread=this;
		
		thread._sample=null;
		thread._result=false;
		thread._running=true;

		var nativeData = __os_storageLookup(BBGame.Game().PathToUrl(this._path));
		var data = __os_Native_To_ArrayBuffer(nativeData);
		
		//load success!
		wa.decodeAudioData
		(
			req.response,

			function(buffer)
			{
				// Decode success!
				thread._sample = new gxtkSample();

				thread._sample.waBuffer = buffer;
				thread._sample.state = 1;

				thread._result = true;
				thread._running = false;
			},

			function()
			{
				// Decode failure!
				thread._running = false;
			}
		);
	}
}
else
{
	BBAsyncSoundLoaderThread.prototype.Start = function()
	{
		this._sample = null;

		if (!this._device.okay)
		{
			return;
		}
		
		var audio = new Audio();

		if (!audio)
		{
			return;
		}
		
		var thread = this;
		
		thread._sample = null;
		thread._result = false;
		thread._running = true;

		audio.src = __os_allocateResource(BBGame.Game().PathToUrl(this._path), false);
		audio.preload = 'auto';
		
		var success = function(e)
		{
			thread._sample = new gxtkSample(audio);
			
			thread._result = true;
			thread._running = false;

			audio.removeEventListener('canplaythrough', success, false);
			audio.removeEventListener('error', error, false);
		}
		
		var error = function(e)
		{
			thread._running = false;

			audio.removeEventListener('canplaythrough', success, false);
			audio.removeEventListener('error', error, false);
		}
		
		audio.addEventListener('canplaythrough', success, false);
		audio.addEventListener('error', error, false);
		
		//voodoo fix for Chrome!
		var timer = setInterval
		(
			function()
			{
				if (!thread._running)
				{
					clearInterval(timer);
				}
			},

			200
		);
		
		audio.load();
	}
}
  
BBAsyncSoundLoaderThread.prototype.IsRunning=function()
{
	return this._running;
}
