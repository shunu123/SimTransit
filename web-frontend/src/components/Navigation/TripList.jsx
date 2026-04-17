import React from 'react';
import { Bus, Clock, ChevronRight, Activity, X } from 'lucide-react';
import { motion } from 'framer-motion';

const TripList = ({ trips, from, to, onTrack, onBack }) => {
    return (
        <div 
            className="w-full h-full flex flex-col p-8 pt-8 overflow-hidden"
        >
            <div className="flex items-center justify-between px-2 mb-10">
                <button 
                    onClick={onBack}
                    className="flex items-center gap-2 group text-white/40 hover:text-white transition-all duration-300"
                >
                    <ChevronRight size={18} className="rotate-180 group-hover:-translate-x-1 transition-transform" />
                    <span className="text-[10px] font-black uppercase tracking-[0.3em]">Back to Planner</span>
                </button>
                <div className="flex items-center gap-2 px-3 h-8 bg-white/10 rounded-full border border-white/10 shadow-lg shadow-[#4ade80]/5">
                    <div className="w-1.5 h-1.5 bg-[#4ade80] rounded-full shadow-[0_0_10px_rgba(74,222,128,0.5)]" />
                    <span className="text-[10px] font-black text-white/90 uppercase tracking-widest leading-none">{trips.length} Results</span>
                </div>
            </div>

            <div className="flex-1 overflow-y-auto scrollbar-hide space-y-4 pr-1">
                {trips.length === 0 ? (
                    <div className="bg-white/5 rounded-[32px] p-12 text-center border border-white/5 backdrop-blur-xl mt-4 flex items-center justify-center">
                        <p className="text-[11px] text-white/60 font-black uppercase tracking-[0.4em] leading-relaxed">No active routes found</p>
                    </div>
                ) : (
                    trips.map((trip) => {
                        const boardingTime = trip.boarding_time || "00:00";
                        const [hours, minutes] = boardingTime.split(':').map(Number);
                        const duration = trip.duration_minutes || 25; 
                        const arriveMinutes = (minutes + duration) % 60;
                        const arriveHours = (hours + Math.floor((minutes + duration) / 60)) % 24;
                        const arrivalTime = `${String(arriveHours).padStart(2, '0')}:${String(arriveMinutes).padStart(2, '0')}`;

                        return (
                             <div 
                                 key={trip.id}
                                 className="bg-white/5 border border-white/10 rounded-[32px] overflow-hidden flex flex-col transition-all duration-300 shadow-2xl group hover:border-white/20"
                             >
                                 <div className="flex items-center justify-between px-6 h-[80px] border-b border-white/5 bg-white/[0.02]" style={{ height: '80px' }}>
                                     <div className="flex items-center gap-3">
                                         <div className="px-3 py-1 bg-[#d4a843] rounded-lg shadow-lg flex items-center justify-center">
                                             <span className="text-xs font-black text-white tracking-widest leading-none">#{trip.bus_no}</span>
                                         </div>
                                         {trip.isNightOwl && <Activity size={12} className="text-[#d4a843]" />}
                                     </div>
                                     <span className="text-[11px] font-bold text-white/30 uppercase tracking-widest leading-none">
                                         {duration} mins commute
                                     </span>
                                 </div>

                                 {/* Main Content: Compact Vertical Timeline */}
                                 <div className="flex items-start gap-8 px-8 py-10">
                                     {/* Vertical Timeline Graphics */}
                                     <div className="flex flex-col items-center gap-1 self-stretch pt-2 pb-1 w-6">
                                         <div className="w-2.5 h-2.5 rounded-full bg-[#4ade80] shadow-[0_0_10px_rgba(74,222,128,0.4)]" />
                                         <div className="flex-1 w-[2px] bg-white/20" />
                                         {trip.next_stop_name && (
                                             <>
                                                 <div className="w-1.5 h-1.5 rounded-full bg-blue-400 shadow-[0_0_8px_rgba(96,165,250,0.4)]" />
                                                 <div className="flex-1 w-[2px] bg-white/20" />
                                             </>
                                         )}
                                         <div className="w-2.5 h-2.5 rounded-full bg-[#d4a843] shadow-[0_0_10px_rgba(212,168,67,0.2)]" />
                                     </div>

                                     {/* Trip Details */}
                                     <div className="flex-1 flex flex-col gap-8">
                                         {/* Departure */}
                                         <div className="flex items-center justify-between">
                                             <div className="flex flex-col gap-0.5">
                                                 <span className="text-sm font-black text-white tracking-tight uppercase truncate max-w-[150px]">{from || "Origin"}</span>
                                                 <span className="text-[9px] font-bold text-white/60 uppercase tracking-[0.2em]">Departure Point</span>
                                             </div>
                                             <span className="font-mono text-base font-bold text-white tracking-tighter">{boardingTime}</span>
                                         </div>

                                         {/* Next Stop */}
                                         {trip.next_stop_name && (
                                             <div className="flex items-center justify-between opacity-80">
                                                 <div className="flex flex-col gap-0.5">
                                                     <span className="text-xs font-bold text-white tracking-tight uppercase truncate max-w-[150px]">{trip.next_stop_name}</span>
                                                     <span className="text-[8px] font-bold text-blue-400 uppercase tracking-[0.2em]">Next Stop</span>
                                                 </div>
                                                 <span className="font-mono text-sm font-bold text-white tracking-tighter">
                                                     {trip.next_stop_arrival
                                                         ? new Date(trip.next_stop_arrival).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false })
                                                         : (trip.next_stop_sched_arrival ? trip.next_stop_sched_arrival.substring(0, 5) : "--:--")}
                                                 </span>
                                             </div>
                                         )}

                                         {/* Arrival */}
                                         <div className="flex items-center justify-between">
                                             <div className="flex flex-col gap-0.5">
                                                 <span className="text-sm font-black text-white tracking-tight uppercase truncate max-w-[150px]">{to || "Destination"}</span>
                                                 <span className="text-[9px] font-bold text-white/60 uppercase tracking-[0.2em]">Estimated Arrival</span>
                                             </div>
                                             <div className="flex flex-col items-end gap-1">
                                                 <span className="font-mono text-lg font-black text-[#d4a843] tracking-tighter">{arrivalTime}</span>
                                                 <div className="px-2 py-0.5 bg-[#4ade80]/10 border border-[#4ade80]/20 rounded-full">
                                                     <span className="text-[8px] font-black text-[#4ade80] uppercase tracking-widest">On Time</span>
                                                 </div>
                                             </div>
                                         </div>
                                     </div>
                                 </div>

                                 {/* Footer Action */}
                                 <div className="px-6 pb-6 pt-2 flex justify-end">
                                     <button 
                                         onClick={() => onTrack(trip)}
                                         className="flex items-center gap-2 px-5 py-2.5 bg-white/5 hover:bg-[#d4a843] border border-white/10 hover:border-transparent rounded-full text-[10px] font-black text-white/80 hover:text-white transition-all group/btn shadow-xl"
                                     >
                                         TRACK LIVE
                                         <ChevronRight size={14} />
                                     </button>
                                 </div>
                             </div>
                        );
                    })
                )}
            </div>
        </div>
    );
};

export default TripList;
