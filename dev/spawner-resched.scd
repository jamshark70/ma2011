// unknown: what is 'rho' typically in the anglepoint?
// seems to peak about 0.25, more typically 0.12 - 0.2 when active

u.remove;
u = SimpleController(BP(\ml));
u.put(\allPtsReceived, nil);

u.put(\allPtsReceived, { |obj|
	obj.anglePoint.rho.postln;
});


// IMPORTANT

do((0..11)) { |i|
	var	name = i.asMIDINote(5).reject(_.isDecDigit).replace("#", "s").toLower.asSymbol;
	Mode(\default).v.copy.root_(i)/*.transposeRoot(2)*/ => Mode(name);
};



// crap. doesn't work b/c 'nexttime' is already decided in the Spawner
// can't move 'nexttime' earlier...

p = Pspawner({ |sp|
	x = sp;
	loop { sp.now.debug("time"); sp.wait(1) };
}).play(quant: 1);

q = p.stream;

x.par(Pn((play: { x.now.debug("\tevent") }), 1), 0.5);
p.stop;
p = EventStreamPlayer(q, Event.default).play(quant: [1, 0.5]);

p.stop;


// don't pull them into the spawner:
// run them separately and track their endings

(
PR(\abstractProcess).clone({
	~restEvent = Event.silent(1);
	~autoStopChildren = true;
	~prep = {
		~players = IdentityDictionary.new;
		~userprep.();
		currentEnvironment
	};

	// just in case I need something else here later
	~freeCleanup = {
		~userfree.();
	};

	~addStream = { |pattern, quant|
		var	esp = pattern.play(~clock, ~event, quant);
		~players.put(
			esp,
			SimpleController(esp).put(\stopped, e {
				~players.at(esp).remove;  // dump the dependant
				~players.removeAt(esp);
				~userRemoveStreamPlayer.(esp);
				// ~players.size.debug("got stopped notification, remaining");
			});
		);
		~userAddStreamPlayer.(esp);
		esp
	};
	
	~stopCleanup = {
		// note, can't use keysDo
		// the point of using keys.do is to iterate over a collection
		// that is independent of the collection from which items will be removed
		// have to do this now: if the SimpleController fires after 'free', kaboom
		if(~autoStopChildren ? true) {
			~players.keys.do { |esp|
				~players.at(esp).remove;  // release the SimpleController dependant
				~players.removeAt(esp);   // remove the esp from the collection
				esp.stop;
			};
		};
		~userStop.();
	};

	~asPattern = {
		Pn(~restEvent, inf)  // need a dummy to keep BP alive
	};
}) => PR(\streamTrack);
)

(
BP(\st).free;

if(Mode.exists(\d).not) { ModalSpec(#[0, 2, 4, 5, 7, 9, 11], 12, 2) => Mode(\d) };

PR(\streamTrack).chuck(BP(\st), nil, (
	event: (eventKey: \voicerNote, midi: true, midiNoteToFreq: _.midicps),
	restEvent: (freq: #[], delta: 1, length: 1, gate: 1),
	model: BP(\ml),
	alwaysReset: true,
	userprep: {
		~syncMax = GenericGlobalControl(\syncMax, nil, 0.3);
		~gridStreams = Array.newClear(~model.points.size);
		~oldChords = ~chords;
		currentEnvironment
	},
	userfree: { ~syncMax.free },
	useGui: { |vpi| ~syncMax => VP(vpi) },

	// this should not answer video data if not playing
	preparePlay: {
		~resp = SimpleController(~model).put(\allPtsReceived, e { ~respond.() });
	},
	userStop: { ~resp.remove },

	magThresh: 60000,
	// lastCentroid: Point(0, 0),
	pquant: 0.25,

	respond: {
		var pts, esp;
		pts = [(0..24), ~model.points/*[ind]*/].flop
		.sort { |a, b| a[1].mag.last > b[1].mag.last };
		if(~gridStreams[pts[0][0]].isNil and: { pts[0][1].mag.last >= ~magThresh }) {
			// pass the point to makePattern
			esp = ~addStream.(~makePattern.(pts[0][1], pts[0][0]), ~pquant);
			~gridStreams[pts[0][0]] = esp;
		};
	},

	chords: [
		#[21, 25, 28, 31, 33],
		#[28, 31, 32, 36, 40],
		#[29, 33, 34, 37, 42],
		#[31, 36, 37, 40, 46],
		#[34.5, 38, 43, 44, 47]
	].flop,

	// centroid x
	// centroid y
	
	// sync target, sync range, sync time
	// pitch (most active pt)

	freq: { |pt, i| ~chords[4 - (i % 5)][i div: 5] },
	oldFreq: { |pt, i| (~oldChords ? ~chords)[4 - (i % 5)][i div: 5] },
	delta: { Pexprand(0.1, 0.6, inf) },
	quantize: Pfunc({ ~model.centroid.y * 0.5 + 0.5 }),
	length: Pkey(\delta) * Pexprand(0.8, 1.7, inf),
	gate: { |pt, i| Pgeom.fromEndpoints(0.8, 0.01, ~numEvents) },
	pan: Pfunc({ ~model.centroid.x }),
	mode: \d,
	modePat: { BPStream(\mode) },
	blend: 1,
	mod_ratio: { rrand(1, 4) },
	mod_lev: Pfunc({ ~model.centroid.y.linlin(-1, 1, 6.0, 0.3) }),

	qcurve: -4,
	// tried it, didn't like it - effect was not clear
	// quantize: { |pt, i|
	// 	var env = Env([0, ~syncMax.value], [1], ~qcurve), p;
	// 	p = Pseries.fromEndpoints(0, 1, (~numEvents * 0.75).asInteger).collect { |i| env.at(i) };
	// },

	quantize: { ~syncMax },
	gate: { |pt, i|
		var n = rrand(2, 4), env, large = (~numEvents * 0.8).asInteger;
		env = Env(
			([0.8, 0.1] ! n).flat,
			[large, ~numEvents - large]
			.collect { |z, i| z.partition(n - i, 1) }
			.lace(n*2 - 1),
			~qcurve ?? { -4 }
		);
		Pseries(0, 1, ~numEvents).collect({ |i| env.at(i) })
	},

	calcNumEvents: { /*|pt, i|*/ (~model.normmag * 25).round.asInteger + 9 },

	makePattern: { |pt, i|
		~numEvents = ~calcNumEvents.(pt, i);  // bah, tired of passing everything as args
		Pbind(
			\mode, ~modePat.(pt, i),
			\oldDegree, ~oldFreq.(pt, i),
			\degree, ~freq.(pt, i),
			\blend, BPStream(\blend),
			\freq, Pfunc({ |ev|
				var	f0 = ev[\oldDegree].unmapMode(ev[\oldMode] ? ev[\mode]),
					f1 = ev[\degree].unmapMode(ev[\mode]);
				blend(f0, f1, ev[\blend])
			}),
			\mod_ratio, ~mod_ratio.(pt, i),
			\mod_lev, ~mod_lev.(pt, i),
			\quantize, ~quantize.(pt, i),
			\delta, ~delta.(pt, i).collect { |dur, ev|
				var	rounded = min(~pquant, dur.round(~pquant)) - (thisThread.beats % ~pquant);
				if(rounded < ~pquant) { rounded = rounded + ~pquant };
				dur.blend(rounded, ev[\quantize])
			},
			\length, ~length.(pt, i),
			\gate, ~gate.(pt, i),
			\pan, ~pan.(pt, i)
		)
	},
	userRemoveStreamPlayer: { |esp|
		~gridStreams = ~gridStreams.replace(esp, #[nil]);
	}
));
0.25 => BP(\st);
if(VC.exists(\pl)) { VC(\pl) => BP(\st) };
)

BP(\st) => MT(1);
BP(\st) => VP(0);

BP(\st).stop;
BP(\st).play;
BP(\st).isPlaying;

BP(\st).gridStreams = Array.newClear(25);

BP(\st).qcurve = -4;
BP(\st).quantize = { |pt, i|
	var env = Env([0, ~syncMax.value], [1], ~qcurve), p;
	p = Pseries.fromEndpoints(0, 1, (~numEvents * 0.75).asInteger).collect { |i| env.at(i) };
};

BP(\st).quantize = { ~syncMax };
BP(\st).gate = { |pt, i|
	var n = rrand(2, 4), env, large = (~numEvents * 0.8).asInteger;
	env = Env(
		([0.8, 0.1] ! n).flat,
		[large, ~numEvents - large]
			.collect { |z, i| z.partition(n - i, 1) }
			.lace(n*2 - 1),
		~qcurve ?? { -4 }
	);
	Pseries(0, 1, ~numEvents).collect({ |i| env.at(i) })
};


Mode(\d).v.transposeRoot(newRoot: 0).postcs
Mode(\default).v.copy.root_(4).postcs.transposeRoot(2).postcs

do((0..11)) { |i|
	var	name = i.asMIDINote(5).reject(_.isDecDigit).replace("#", "s").toLower.asSymbol;
	Mode(\default).v.copy.root_(i).transposeRoot(2) => Mode(name);
};

// kind of weird Gavin Bryars-y thing going on here
BP(\st).mode = Pstutter(Pwhite(100, 190, inf), Pxrand(#[a, as, b, c, cs, d, ds, e, f, fs, g, gs], inf).trace);

#[a, as, b, c, cs, d, ds, e, f, fs, g, gs].do { |key| [key, Mode(key).v.asCompileString].postln };

BP(\st).v[\asPattern].postcs
BP(\st).origChords = BP(\st).chords;

BP(\st).chordChangeBeats = Pwhite(12, 20, inf);
BP(\st).asPattern = {
	~chordChangeBeatsStream ?? { ~makeStreamForKey.(\chordChangeBeats) };
	Prout({ |inevent|
		var beats;
		loop {
			~changeChords.(inevent);
			beats = ~chordChangeBeatsStream.next(inevent);
			beats.do {
				inevent = 1.yield;
			};
			if(beats.frac != 0) { inevent = beats.frac.yield };
		};
	})
};

BP(\st).changeChordMode = \patRejectLastN.eval(Pxrand(#[a, as, b, c, cs, d, ds, e, f, fs, g, gs], inf), 6);
BP(\st).xIntervals = Pwhite(3, 6, inf);
BP(\st).yIntervals = Pwhite(1, 4, inf);

BP(\st).changeChords = { |inevent|
	~oldMode = ~mode;
	~mode = ~changeChordModeStream.next(inevent);
	~oldChords = ~chords;
	~chords = Pseries(21, ~xIntervals, ~model.dim).collect { |bass|
		Pseries(bass, ~yIntervals, ~model.dim).asStream.all
	}.asStream.all;
	// not convinced... maybe blend with long tones
	~blend = Plazy({ Env(#[0, 1], [rrand(0.4, 0.8)]) });
};

BP(\st).chords.do(_.postln); ""

BP(\st).listVars

BP(\st).event[\midiNoteToFreq] = _.midicps;

BP(\st).event[\midiNoteToFreq].def.dumpByteCodes

BP(\st).mod_lev = Pfunc({ ~model.centroid.y.linlin(-1, 1, 6.0, 0.3) });



// arpeggiator; reset pattern on "wipe" gesture (or any fast motion)
// use streamtrack to have multiple layers at once
(
BP(\arp).free;

PR(\streamTrack).chuck(BP(\arp), nil, (
	// set ~model at chuck time
	event: (eventKey: \voicerNote),
	model: BP(\ml),
	alwaysReset: true,
	pquant: 0.25,
	magThresh: 0.3,  // ??
	angleThresh: 0.6,  // radians
	maxPlayers: 8,
	rhoScale: 7.5,  // assuming anglePoint.rho peaking about 0.25
	restEvent: (freq: #[], delta: 1, length: 1, gate: 1),
	userprep: {
		~syncMax = GenericGlobalControl(\syncMax, nil, 1);
	},
	userfree: { ~syncMax.free },
	useGui: { |vpi| ~syncMax => VP(vpi) },

	preparePlay: {
		~angleDiffs = 0 ! 5;
		~angleI = 0;
		~prevAngle = 0;
		~changeChordModeStream ?? { ~makeStreamForKey.(\changeChordMode) };
		// if(~chords.isNil) { ~changeChords.() };
		~resp = SimpleController(~model).put(\allPtsReceived, e { ~respond.() });
	},
	userStop: { ~resp.remove },

	xIntervals: Pwhite(3, 6, inf),
	yIntervals: Pwhite(1, 4, inf),
	changeChordMode: \patRejectLastN.eval(Pxrand(#[a, as, b, c, cs, d, ds, e, f, fs, g, gs], inf), 6),
	chordChangeBeats: Pwhite(8, 15, inf),

	changeChords: { |inevent|
		// ~oldMode = ~mode;
		~mode = ~changeChordModeStream.next(inevent);
		// ~oldChords = ~chords;
		~chords = Pseries(21, ~xIntervals, ~model.dim).collect { |bass|
			Pseries(bass, ~yIntervals, ~model.dim).asStream.all
		}.asStream.all;
		// not convinced... maybe blend with long tones
		~blend = Plazy({ Env(#[0, 1], [rrand(0.4, 0.8)]) });
	},

	respond: {
		var diff = ~model.anglePoint.theta - ~prevAngle,
		temp;
		if(diff.inclusivelyBetween(-pi, pi).not) { diff = (2pi - diff).wrap(-pi, pi) };
		~angleI = (~angleI + 1) % ~angleDiffs.size;
		~angleDiffs[~angleI] = diff;
		~prevAngle = ~model.anglePoint.theta;
		// heavier lifting only if we pass the threshold test
		if(~players.size < ~maxPlayers and: { ~model.normmag >= ~magThresh }) {
			temp = ~angleDiffs.copy;
			temp.remove(temp.minItem);
			temp.remove(temp.maxItem);
			if(temp.every(_.inclusivelyBetween(~angleThresh.neg, ~angleThresh))) {
				~addStream.(~makePattern.(), ~pquant);
			};
		};
	},

	xPat: { |pt, i|
		// yPat will reuse this
		~incrTempPolar = ~model.anglePoint.asPolar;
		Pseries(~model.centroid.x, cos(~incrTempPolar.theta) * ~incrTempPolar.rho, inf)
		.round.asInteger % ~model.dim
	},
	yPat: { |pt, i|
		var y = ~model.centroid.y, oldY,
		incr = sin(~incrTempPolar.theta) * ~incrTempPolar.rho,
		incrSign = (incr >= 0).binaryValue * 2 - 1,
		xdiff = Pdiff(Pkey(\x)).asStream;
		Prout({ |inval|
			loop {
				inval = (~model.dim - 1 - y.trunc.asInteger).yield;
				oldY = y;
				y = y - incr;
				// x is calculated by floats but passed here as integers
				// so this checks the actual x coordinate's movement
				if(xdiff.next(inval) == 0 and: { y.round == oldY.round }) {
					y = y - incrSign;
				};
				y = y % ~model.dim;
			}
		})
	},
	freq: { |pt, i|
		// well, I shouldn't need wrapAt but somehow 'y' is negative sometimes?? WTF??
		Pfunc({ |ev| ~chords.wrapAt(ev[\y]).wrapAt(ev[\x]) })
	},
	delta: { Pexprand(0.2, 0.9, ~numEvents) },
	// quantize: Pfunc({ ~model.centroid.y * 0.5 + 0.5 }),
	length: Pkey(\delta), // * Pexprand(0.8, 1.7, inf),
	// frozen at start time - may try following x coordinate
	pan: Pfunc({ ~model.centroid.x }),
	mode: \d,
	modePat: { BPStream(\mode) },
	mod_ratio: 1, // { rrand(1, 4) },
	mod_lev: Pfunc({ ~model.centroid.y.linlin(-1, 1, 1.6, 0.15) }),
	// maybe exponentialize
	car_buf: Pfunc({ (~model.centroid.y * (-0.5) + 0.5) * 7.9 + VC(\pl).env.cb.first.bufnum }),

	qcurve: -4,

	quantize: { ~syncMax },
	gate: 0.2,

	calcNumEvents: { /*|pt, i|*/ (~model.normmag * 25).round.asInteger + 9 },

	makePattern: { // |pt, i|
		~numEvents = ~calcNumEvents.()/*.(pt, i)*/;  // bah, tired of passing everything as args
		Pbind(
			\mode, ~modePat.()/*.(pt, i)*/,
			\x, ~xPat.()/*.(pt, i)*/,
			\y, ~yPat.()/*.(pt, i)*/,
			\freq, ~freq.()/*.(pt, i)*/,
			\mod_ratio, ~mod_ratio.()/*.(pt, i)*/,
			\mod_lev, ~mod_lev.()/*.(pt, i)*/,
			\quantize, ~quantize.()/*.(pt, i)*/,
			\delta, ~delta.()/*.(pt, i)*/.collect { |dur, ev|
				var	rounded = min(~pquant, dur.round(~pquant)) - (thisThread.beats % ~pquant);
				if(rounded < ~pquant) { rounded = rounded + ~pquant };
				dur.blend(rounded, ev[\quantize])
			},
			\length, ~length.()/*.(pt, i)*/,
			\gate, ~gate.()/*.(pt, i)*/,
			\pan, ~pan.()/*.(pt, i)*/,
			\car_buf, ~car_buf.()
		)
	},

	asPattern: {
		~chordChangeBeatsStream ?? { ~makeStreamForKey.(\chordChangeBeats) };
		Prout({ |inevent|
			var beats;
			loop {
				~changeChords.(inevent);
				beats = ~chordChangeBeatsStream.next(inevent);
				beats.do {
					inevent = 1.yield;
				};
				if(beats.frac != 0) {
					inevent = beats.frac.yield;
				};
			};
		})
	}
));
0 => BP(\arp);
if(VC.exists(\pl)) { VC(\pl) => BP(\arp) };
)

if(MT.exists(1).not) { MT(1).gui };
BP(\arp) => MT(1);

BP(\arp).play;
BP(\arp).stop;

BP(\arp).alwaysReset;
BP(\arp).v[\preparePlay].postcs
BP(\arp).resp.inspect
BP(\arp).model

BP(\arp).prevAngle

BP(\ml).dependants.insp

BP(\arp).magThresh = 0.3;
BP(\arp).angleThresh = 0.6;

BP(\arp).restEvent = (freq: #[], delta: 1, length: 1, gate: 1);

BP(\arp).makePattern = { // |pt, i|
		~numEvents = ~calcNumEvents.()/*.(pt, i)*/;  // bah, tired of passing everything as args
		DebugPbind(
			\mode, ~modePat.()/*.(pt, i)*/,
			\x, ~xPat.()/*.(pt, i)*/,
			\y, ~yPat.()/*.(pt, i)*/,
			\freq, ~freq.()/*.(pt, i)*/,
			\mod_ratio, ~mod_ratio.()/*.(pt, i)*/,
			\mod_lev, ~mod_lev.()/*.(pt, i)*/,
			\quantize, ~quantize.()/*.(pt, i)*/,
			\delta, ~delta.()/*.(pt, i)*/.collect { |dur, ev|
				var	rounded = min(~pquant, dur.round(~pquant)) - (thisThread.beats % ~pquant);
				if(rounded < ~pquant) { rounded = rounded + ~pquant };
				dur.blend(rounded, ev[\quantize])
			},
			\length, ~length.()/*.(pt, i)*/,
			\gate, ~gate.()/*.(pt, i)*/,
			\pan, ~pan.()/*.(pt, i)*/
		)/*.collect { |ev|
			#[x, y, freq].collect(ev[_]).debug("x, y, freq");
			ev
		}*/
	};

BP(\arp).magDecay = 0.63095734448019;
BP(\arp).currentMag = 0;
BP(\arp).respond = {
	var diff = ~model.anglePoint.theta - ~prevAngle,
	temp;
	if(diff.inclusivelyBetween(-pi, pi).not) { diff = (2pi - diff).wrap(-pi, pi) };
	~angleI = (~angleI + 1) % 5;
	~angleDiffs[~angleI] = diff;
	~prevAngle = ~model.anglePoint.theta;
	if(~model.normmag > ~currentMag) {
		~currentMag = ~model.normmag;
	} {
		~currentMag = ~currentMag * ~magDecay;
	};
	// heavier lifting only if we pass the threshold test
	if((~players.size < ~maxPlayers) and: { ~currentMag >= ~magThresh }) {
		temp = ~angleDiffs.copy;
		temp.remove(temp.minItem);
		temp.remove(temp.maxItem);
		if(temp.every(_.inclusivelyBetween(~angleThresh.neg, ~angleThresh))) {
			~addStream.(~makePattern.(), ~pquant).debug("fired");
		};
	};
};

BP(\arp).chords;
BP(\arp).changeChords;

BP(\arp).quantize = Pfunc({ ~model.centroid.y * 0.5 + 0.5 });

BP(\arp).delta = { Pexprand(0.2, 0.9, ~numEvents) };
BP(\arp).pquant

TempoClock.default.gui;

BP(\arp).maxPlayers = 4;
BP(\arp).players.size

BP(\arp).preparePlay = {
		~angleDiffs = 0 ! 5;
		~angleI = 0;
		~prevAngle = 0;
		~changeChordModeStream ?? { ~makeStreamForKey.(\changeChordMode) };
		if(~chords.isNil) { ~changeChords.() };
		~resp = SimpleController(~model).put(\allPtsReceived, e { ~respond.() });
	};

BP(\arp).v[\quantize].postcs

BP(\arp).useGui = { |vpi| ~syncMax => VP(vpi) };


VC(\pl).v.trace

VC(\pl).env.cb[0].plotWavetable