import { Clock, MapPin, CheckCircle2, Loader2, Bus } from 'lucide-react';

const LiveTimeline = ({ routeStops, selectedBus, busLocation, tripStats, tripDuration = 25 }) => {
  // Find nearest stop if busLocation is provided
  const findCurrentStop = () => {
    if (!busLocation || !routeStops.length) return 0;
    let nearestIdx = 0;
    let minDist = Infinity;
    
    routeStops.forEach((stop, idx) => {
      const d = Math.sqrt(Math.pow(stop.lat - busLocation.lat, 2) + Math.pow(stop.lng - busLocation.lng, 2));
      if (d < minDist) {
        minDist = d;
        nearestIdx = idx;
      }
    });
    return nearestIdx;
  };

  const currentStopIndex = findCurrentStop();

  if (!routeStops || routeStops.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-64 opacity-20 border-2 border-dashed border-white/10 rounded-[32px] mx-4">
        <Loader2 className="mb-4" size={32} />
        <p className="text-[10px] font-black uppercase tracking-[0.4em]">Initializing Timeline...</p>
      </div>
    );
  }

  const journeyDist = tripStats?.distance || 0;
  const journeyDur = tripStats?.duration || 0;

  return (
    <div className="relative px-4 py-2">
      {/* JOURNEY METRICS HEADER */}
      <div className="grid grid-cols-2 gap-4 mb-12">
        <div className="bg-white/[0.03] border border-white/[0.06] rounded-[var(--radius-lg)] p-6 relative overflow-hidden group hover:border-white/10 transition-colors">
          <div className="absolute top-0 right-0 w-20 h-20 bg-blue-500/10 blur-3xl rounded-full translate-x-1/2 -translate-y-1/2" />
          <div className="text-[10px] font-black text-white/30 uppercase tracking-[0.2em] mb-2">Distance</div>
          <div className="text-3xl font-[1000] text-white tracking-tighter">
            {journeyDist.toFixed(1)}<span className="text-xs ml-1 text-white/20">KM</span>
          </div>
        </div>
        <div className="bg-white/[0.03] border border-white/[0.06] rounded-[var(--radius-lg)] p-6 relative overflow-hidden group hover:border-white/10 transition-colors">
          <div className="absolute top-0 right-0 w-20 h-20 bg-[var(--gold)]/10 blur-3xl rounded-full translate-x-1/2 -translate-y-1/2" />
          <div className="text-[10px] font-black text-white/30 uppercase tracking-[0.2em] mb-2">Est. Time</div>
          <div className="text-3xl font-[1000] text-[var(--gold)] tracking-tighter shadow-[0_0_30px_rgba(245,158,11,0.1)]">
            {journeyDur}<span className="text-xs ml-1 text-white/20">MIN</span>
          </div>
        </div>
      </div>

      <div className="relative ml-2 py-6">
        {/* BACKGROUND TRACK */}
        <div className="absolute left-[11px] top-8 bottom-8 w-[2px] bg-white/[0.05] rounded-full" />
        
        {/* ACTIVE PROGRESS TRACK */}
        <div 
          style={{ height: `${(currentStopIndex / Math.max(1, routeStops.length - 1)) * 100}%` }}
          className="absolute left-[11px] top-8 w-[2px] bg-gradient-to-b from-[var(--emerald)] via-[var(--gold)] to-transparent rounded-full shadow-[0_0_20px_rgba(245,158,11,0.2)] z-0"
        />

        {/* BUS INDICATOR ON TRACK */}
        <div
            style={{ top: `calc(32px + ${(currentStopIndex / Math.max(1, routeStops.length - 1)) * 100}% * (100% - 64px) / 100)` }}
            className="absolute left-[2px] w-5 h-5 bg-white rounded-full shadow-2xl z-20 flex items-center justify-center border-2 border-[var(--gold)]"
        >
            <Bus size={10} className="text-[var(--gold)]" />
        </div>

        <div className="flex flex-col gap-24" style={{ gap: '96px' }}>
          {routeStops.map((stop, idx) => {
            const isCompleted = idx < currentStopIndex;
            const isActive = idx === currentStopIndex;
            const isUpcoming = idx > currentStopIndex;
            
            // Simple ETA estimation
            const durationToUse = tripStats?.duration || tripDuration;
            const minsPerStop = Math.ceil(durationToUse / (routeStops.length || 1));
            const etaMins = (idx - currentStopIndex) * minsPerStop;

            return (
              <div 
                key={stop.stop_id || idx}
                className="relative flex items-start gap-10 group"
              >
                {/* NODE ICON */}
                <div className="relative z-10 mt-1.5 flex items-center justify-center w-6">
                  {isActive ? (
                    <div className="relative">
                      <div className="w-6 h-6 rounded-full bg-white border-[4px] border-[var(--gold)] shadow-[0_0_20px_rgba(245,158,11,0.4)] flex items-center justify-center z-10 scale-110">
                          <MapPin size={10} className="text-[var(--gold)] stroke-[4px]" />
                      </div>
                    </div>
                  ) : isCompleted ? (
                    <div className="w-5 h-5 rounded-full bg-[var(--gold)]/10 border border-[var(--gold)]/20 flex items-center justify-center">
                      <CheckCircle2 size={10} className="text-[var(--gold)]/40" />
                    </div>
                  ) : (
                    <div className="w-5 h-5 rounded-full bg-black border-2 border-white/10 group-hover:border-[var(--gold)]/40 transition-all duration-500" />
                  )}
                </div>

                {/* STOP DETAILS */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between gap-4 mb-2">
                    <h4 className={`text-lg font-black tracking-tighter truncate transition-all duration-500 ${
                      isActive ? 'text-white scale-105 origin-left' : 
                      isCompleted ? 'text-white/10' : 'text-white/40 group-hover:text-white'
                    }`}>
                      {stop.stop_name || stop.name || stop.stpnm}
                    </h4>
                    
                    {isActive ? (
                      <div className="px-3 py-1 bg-[var(--gold)]/10 border border-[var(--gold)]/20 rounded-lg">
                        <span className="text-[9px] font-[1000] text-[var(--gold)] uppercase tracking-[0.3em]">Now</span>
                      </div>
                    ) : isUpcoming && (
                      <div className="flex items-center gap-1.5 opacity-20 group-hover:opacity-100 transition-opacity">
                        <Clock size={12} className="text-white" />
                        <span className="text-[10px] font-black text-white tracking-widest">{etaMins}m</span>
                      </div>
                    )}
                  </div>

                  <div className="flex items-center gap-3">
                      <p className={`text-[10px] font-[1000] uppercase tracking-[0.4em] transition-colors ${
                          isActive ? 'text-[var(--gold)]' : 
                          isCompleted ? 'text-white/5' : 'text-white/10 group-hover:text-white/20'
                      }`}>
                          {isActive ? 'Current Stop' : isCompleted ? 'Completed' : 'Next Stop'}
                      </p>
                      {isUpcoming && <div className="h-[1px] flex-1 bg-white/[0.04] rounded-full" />}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};

export default LiveTimeline;
