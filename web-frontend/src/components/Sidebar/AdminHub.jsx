import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ShieldCheck, Activity, Users, AlertTriangle, Bus, Clock, ChevronRight, ArrowLeft, Search } from 'lucide-react';

const AdminHub = ({ onTrack, onOpenSearch, stats }) => {
    const [step, setStep] = useState('overview'); // overview, ledger, incidents
    const [activeTrips, setActiveTrips] = useState([]);
    const [incidents, setIncidents] = useState([
        { id: 1, type: 'Delay', route: 'R-101', msg: 'Traffic at Main Gate', ts: '2 mins ago' },
        { id: 2, type: 'Breakdown', route: 'R-502', msg: 'Mechanical issue near Terminal', ts: '10 mins ago' }
    ]);

    useEffect(() => {
        const mockTrips = [
            { id: 101, bus_no: 'B-201', route_name: 'Campus Express', driver: 'Arun', status: 'Active', delay: 2 },
            { id: 102, bus_no: 'B-305', route_name: 'Metro Link', driver: 'Karan', status: 'Active', delay: 5 },
            { id: 103, bus_no: 'B-112', route_name: 'East Hub', driver: 'Siva', status: 'Delayed', delay: 12 },
            { id: 104, bus_no: 'B-404', route_name: 'West Wing', driver: 'Priya', status: 'Completed', delay: 0 }
        ];
        setActiveTrips(mockTrips);
    }, []);

    const containerVariants = {
        hidden: { opacity: 0, x: 20 },
        visible: { 
            opacity: 1, 
            x: 0, 
            transition: { staggerChildren: 0.1, duration: 0.4, ease: [0.4, 0, 0.2, 1] } 
        },
        exit: { opacity: 0, x: -20, transition: { duration: 0.3 } }
    };

    const itemVariants = {
        hidden: { opacity: 0, y: 10 },
        visible: { opacity: 1, y: 0 }
    };

    const renderOverview = () => (
        <motion.div 
            key="overview"
            variants={containerVariants}
            initial="hidden"
            animate="visible"
            exit="exit"
            className="flex flex-col gap-6"
        >
            {/* ADMIN HEADER */}
            <div className="px-2">
                <div className="flex items-center gap-2 mb-2">
                    <div className="px-2 py-0.5 bg-[var(--accent)]/10 border border-[var(--accent)]/20 rounded-md">
                        <span className="text-[8px] font-black text-[var(--accent)] uppercase tracking-[0.2em]">Master Admin</span>
                    </div>
                </div>
                <h1 className="text-3xl font-black text-white tracking-tighter leading-none mb-1">
                    Fleet Hub
                </h1>
                <p className="text-[11px] font-bold text-white/40 uppercase tracking-widest leading-relaxed">System Command Center</p>
            </div>

            {/* QUICK STATS CARDS */}
            <div className="grid grid-cols-2 gap-4">
                <motion.div variants={itemVariants} className="p-5 bg-white/5 border border-white/5 rounded-[28px] flex flex-col gap-2">
                    <span className="text-[10px] font-black text-white/20 uppercase tracking-widest">Active Fleet</span>
                    <span className="text-3xl font-black text-white">24</span>
                    <span className="text-[9px] font-bold text-[#4ade80] uppercase tracking-widest">+12% healthy</span>
                </motion.div>
                <motion.div variants={itemVariants} className="p-5 bg-white/5 border border-white/5 rounded-[28px] flex flex-col gap-2">
                    <span className="text-[10px] font-black text-white/20 uppercase tracking-widest">Live Load</span>
                    <span className="text-3xl font-black text-white">1.2k</span>
                    <span className="text-[9px] font-bold text-white/30 uppercase tracking-widest">Across campus</span>
                </motion.div>
            </div>

            {/* NAVIGATION ACTIONS */}
            <div className="flex flex-col gap-4 mt-2">
                <motion.button 
                    variants={itemVariants}
                    onClick={() => setStep('ledger')}
                    className="group relative p-6 bg-white/5 border border-white/5 rounded-[32px] hover:bg-white/10 transition-all text-left"
                >
                    <div className="flex items-center justify-between mb-4">
                        <div className="w-12 h-12 rounded-2xl bg-white/5 flex items-center justify-center text-white/40 group-hover:bg-white group-hover:text-black transition-all">
                            <Bus size={24} />
                        </div>
                        <ChevronRight size={20} className="text-white/20 group-hover:text-white transition-all outline-none" />
                    </div>
                    <h3 className="text-xl font-black text-white mb-1">Live Ledger</h3>
                    <p className="text-[10px] font-bold text-white/40 uppercase tracking-widest">Detailed trip monitoring</p>
                </motion.button>

                <motion.button 
                    variants={itemVariants}
                    onClick={() => setStep('incidents')}
                    className="group relative p-6 bg-red-500/5 border border-red-500/10 rounded-[32px] hover:bg-red-500/10 transition-all text-left"
                >
                    <div className="flex items-center justify-between mb-4">
                        <div className="w-12 h-12 rounded-2xl bg-red-500/10 flex items-center justify-center text-red-500 group-hover:bg-red-500 group-hover:text-white transition-all">
                            <AlertTriangle size={24} />
                        </div>
                        <div className="px-2 py-0.5 bg-red-500 text-white rounded-md text-[8px] font-black uppercase tracking-widest group-hover:scale-110 transition-transform">
                            {incidents.length} New
                        </div>
                    </div>
                    <h3 className="text-xl font-black text-white mb-1">Incident Report</h3>
                    <p className="text-[10px] font-bold text-white/40 uppercase tracking-widest">System alerts & issues</p>
                </motion.button>

                {/* MANUAL SEARCH ADAPTATION */}
                <motion.button 
                    variants={itemVariants}
                    onClick={onOpenSearch}
                    className="group relative p-6 bg-white/5 border border-white/5 rounded-[32px] overflow-hidden hover:bg-white/10 transition-all text-left"
                >
                    <div className="flex items-center justify-between mb-4">
                        <div className="w-12 h-12 rounded-2xl bg-white/5 flex items-center justify-center text-white/40 group-hover:bg-white group-hover:text-black transition-all">
                            <Search size={24} />
                        </div>
                    </div>
                    <h3 className="text-xl font-black text-white mb-1">Route Planner</h3>
                    <p className="text-[10px] font-bold text-white/40 uppercase tracking-widest">Manual system route sync</p>
                </motion.button>
            </div>
        </motion.div>
    );

    const renderLedger = () => (
        <motion.div 
            key="ledger"
            variants={containerVariants}
            initial="hidden"
            animate="visible"
            exit="exit"
            className="flex flex-col gap-6"
        >
            <div className="flex items-center gap-4 px-2 mb-2">
                <button onClick={() => setStep('overview')} className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center text-white/40 hover:text-white transition-all">
                    <ArrowLeft size={18} />
                </button>
                <div className="flex flex-col">
                    <h2 className="text-2xl font-black text-white tracking-tight leading-none">Live Ledger</h2>
                    <span className="text-[10px] font-bold text-white/30 uppercase tracking-[0.2em]">Active Triplets Monitoring</span>
                </div>
            </div>

            <div className="space-y-3">
                {activeTrips.map(trip => (
                    <motion.button
                        key={trip.id}
                        whileHover={{ x: 4 }}
                        onClick={() => onTrack(trip)}
                        className="w-full flex items-center justify-between p-5 bg-[#0a0a0a] border border-white/5 rounded-[28px] hover:border-[var(--accent)]/50 transition-all group shadow-xl"
                    >
                        <div className="flex-1 flex items-center gap-4 min-w-0">
                            <div className={`w-10 h-10 rounded-2xl bg-white/5 flex items-center justify-center ${
                                trip.status === 'Delayed' ? 'text-red-500 animate-pulse' : 'text-[#4ade80]'
                            }`}>
                                <Bus size={18} />
                            </div>
                            <div className="text-left flex-1 min-w-0">
                                <div className="flex items-center gap-2">
                                    <h5 className="text-sm font-black text-white/90 truncate">{trip.route_name}</h5>
                                    <span className="text-[10px] font-bold text-white/20">#{trip.bus_no}</span>
                                </div>
                                <span className="text-[9px] font-bold text-white/30 uppercase tracking-widest truncate block">{trip.driver} • {trip.status}</span>
                            </div>
                        </div>
                        {trip.delay > 0 && (
                            <div className="flex items-center gap-1 px-2 py-0.5 bg-red-500/10 border border-red-500/20 rounded-md">
                                <Clock size={10} className="text-red-500" />
                                <span className="text-[9px] font-black text-red-500">+{trip.delay}m</span>
                            </div>
                        )}
                    </motion.button>
                ))}
            </div>
        </motion.div>
    );

    const renderIncidents = () => (
        <motion.div 
            key="incidents"
            variants={containerVariants}
            initial="hidden"
            animate="visible"
            exit="exit"
            className="flex flex-col gap-6"
        >
            <div className="flex items-center gap-4 px-2 mb-2">
                <button onClick={() => setStep('overview')} className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center text-white/40 hover:text-white transition-all">
                    <ArrowLeft size={18} />
                </button>
                <div className="flex flex-col">
                    <h2 className="text-2xl font-black text-white tracking-tight leading-none text-red-500">Alert Center</h2>
                    <span className="text-[10px] font-bold text-white/30 uppercase tracking-[0.2em]">Active System Incidents</span>
                </div>
            </div>

            <div className="space-y-4">
                {incidents.map(alert => (
                    <motion.div 
                        key={alert.id}
                        variants={itemVariants}
                        className="p-6 bg-red-500/5 border border-red-500/10 rounded-[32px] relative overflow-hidden group shadow-2xl"
                    >
                        <div className="absolute top-0 right-0 p-4 opacity-5 group-hover:opacity-10 transition-opacity">
                            <AlertTriangle size={64} className="text-red-500" />
                        </div>
                        <div className="relative z-10">
                            <div className="flex items-center justify-between mb-4">
                                <div className="flex items-center gap-2">
                                    <div className="w-2 h-2 bg-red-500 rounded-full animate-ping" />
                                    <span className="text-[10px] font-black text-red-500 uppercase tracking-widest">{alert.type}</span>
                                </div>
                                <span className="text-[9px] font-bold text-white/20 uppercase tracking-widest">{alert.ts}</span>
                            </div>
                            <h6 className="text-[13px] font-black text-white/90 mb-2 leading-tight">{alert.route} - {alert.msg}</h6>
                            <div className="flex items-center gap-2 mt-4 pt-4 border-t border-red-500/10">
                                <div className="w-6 h-6 rounded-full bg-white/5 flex items-center justify-center text-white/20">
                                    <ShieldCheck size={12} />
                                </div>
                                <span className="text-[9px] font-bold text-white/30 uppercase tracking-widest">Reported by Monitoring Unit</span>
                            </div>
                        </div>
                    </motion.div>
                ))}
            </div>
        </motion.div>
    );

    return (
        <div className="flex-1 overflow-y-auto scrollbar-hide p-8 pt-4 pb-20">
            <AnimatePresence mode="wait">
                {step === 'overview' && renderOverview()}
                {step === 'ledger' && renderLedger()}
                {step === 'incidents' && renderIncidents()}
            </AnimatePresence>
        </div>
    );
};
export default AdminHub;
