
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
				~players.size.debug("got stopped notification, remaining");
			});
		);
	};
	
	~stopCleanup = {
		// note, can't use keysDo
		// the point of using keys.do is to iterate over a collection
		// that is independent of the collection from which items will be removed
		// have to do this now: if the SimpleController fires after 'free', kaboom
		~players.keys.do { |esp|
			~players.at(esp).remove;
			~players.removeAt(esp);
			esp.stop;
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
PR(\streamTrack).chuck(BP(\st), nil, (
	event: (eventKey: \voicerNote),
	restEvent: (freq: #[], delta: 1, length: 1, gate: 1),
	model: BP(\ml),
	alwaysReset: true,
	// userprep: {
		
	// },
	// userfree: { ~resp.remove },

	// this should not answer video data if not playing
	preparePlay: {
		~resp = SimpleController(~model).put(\allPtsReceived, e { ~respond.() });
	},
	userStop: { ~resp.remove },

	magThresh: 60000,
	// lastCentroid: Point(0, 0),
	pquant: 0.25,

	respond: {
		var ind, // = ~gridNodes.collectIndicesOfItem(nil),
		pts, ev;
		// if(ind.size > 0) {
			pts = [(0..24), ~model.points/*[ind]*/].flop
			.sort { |a, b| a[1].mag.last > b[1].mag.last };
			if(pts[0][1].mag.last >= ~magThresh) {
				// pass the point to makePattern
				~addStream.(~makePattern.(pts[0][1], ind), ~pquant);
			};
		// };
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
	delta: { Pexprand(0.1, 0.6, inf) },
	quantize: Pfunc({ ~model.centroid.y * 0.5 + 0.5 }),
	length: Pkey(\delta) * Pexprand(0.8, 1.7, inf),
	gate: { |pt, i| Pgeom.fromEndpoints(0.8, 0.01, (pt.normmag * 25).round + 9) },
	pan: Pfunc({ ~model.centroid.x }),

	makePattern: { |pt|		
		DebugPbind(
			\freq, ~freq.(pt, i),
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
	}
));
0.25 => BP(\st);
)

BP(\st).play;
BP(\st).isPlaying;

BP(\st).addStream(Pbind(
	\degree, Pwhite(-7, 7, inf),
	\dur, 0.25
));

BP(\st).addStream(Pbind(
	\degree, Pseries(7, 1, 8),
	\dur, 0.25
));

BP(\st).stop(0);

BP(\st).v[\asPattern].postcs

BP(\st).listVars