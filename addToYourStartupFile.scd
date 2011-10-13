/*
These are some code bits that need to run during sc launch.

Copy the code and paste it into your startup file.

The startup file's location is found by running:

thisProcess.platform.startupFiles;

If the file doesn't exists, make a new file in that location and paste in the code.
*/


StartUp.add {

	{
		var dir = thisProcess.nowExecutingPath ?? { Archive.at(\ma2011dir) },
		pos;

		if(dir.isNil) {
			Error("Path could not be determined. Please save the path into the global Archive, e.g.

Archive.put(\ma2011dir, \"/path/to/ma2011.git\")").throw;
		} {
			pos = dir.find("ma2011.git");
			if(pos.notNil) {
				dir = dir[ .. pos + 9];
			} {
				"The path '%' doesn't contain 'ma2011.git' - some files may not be located."
				.format(dir).warn;
			};
		};
		dir
	} => Func(\ma2011dir);

};
