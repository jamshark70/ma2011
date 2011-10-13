var dir;

if(Func.exists(\ma2011dir)) {
	dir = \ma2011dir.eval;
} {
	Error("Func(\\ma2011dir) doesn't exist. Check your startup configuration (instructions in addToYourStartupFile.scd).").throw;
};

(dir +/+ "common/motion-detection.scd").loadPath;

fork({
	"ps x | grep 'pd-extended' | grep -v 'grep'".unixCmd(e { |result|
		if(result > 0) {
			// pd is not running; load the video patch
			"xdg-open %".format((dir +/+ "vtest/frame-diff5.pd").escapeChar($ )).unixCmd;
		};
	}, postOutput: true);  // postOutput is required to avoid "broken pipe"

	BP(#[mg, ml]).free;
	PR(\motionListener).chuck(BP(\ml), nil, (ptNum: 3, anglebufSize: 5));
	0.25.wait;  // somehow the next doesn't work without a pause
	PR(\motionAngleGui).chuck(BP(\mg), nil, (model: BP(\ml)));
	// BP(\mg) will hit NotificationCenter when pd is up and running
	// other init actions can use this for sync
}, AppClock);