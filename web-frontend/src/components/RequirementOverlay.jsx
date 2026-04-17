import React from 'react';
import { motion } from 'framer-motion';
import { Lock, FileSearch, Sparkles, Terminal } from 'lucide-react';

const RequirementOverlay = () => {
    return (
        <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="fixed inset-0 z-[10000] flex items-center justify-center p-6"
            style={{
                backgroundColor: 'rgba(15, 23, 42, 0.85)',
                backdropFilter: 'blur(24px)',
                fontFamily: "'Inter', sans-serif"
            }}
        >
            {/* Ambient Background orbs for premium feel */}
            <div className="absolute inset-0 overflow-hidden pointer-events-none">
                <motion.div 
                    animate={{ 
                        scale: [1, 1.2, 1],
                        opacity: [0.15, 0.3, 0.15],
                        x: [0, 50, 0],
                        y: [0, -30, 0]
                    }}
                    transition={{ duration: 15, repeat: Infinity, ease: 'linear' }}
                    className="absolute -top-[10%] -right-[10%] w-[500px] h-[500px] rounded-full bg-blue-500/20 blur-[100px]"
                />
                <motion.div 
                    animate={{ 
                        scale: [1.2, 1, 1.2],
                        opacity: [0.1, 0.25, 0.1],
                        x: [0, -40, 0],
                        y: [0, 40, 0]
                    }}
                    transition={{ duration: 12, repeat: Infinity, ease: 'linear' }}
                    className="absolute -bottom-[10%] -left-[10%] w-[400px] h-[400px] rounded-full bg-purple-500/15 blur-[100px]"
                />
            </div>

            <motion.div 
                initial={{ scale: 0.95, y: 10 }}
                animate={{ scale: 1, y: 0 }}
                className="relative max-w-lg w-full bg-white/[0.03] border border-white/[0.08] rounded-[40px] p-12 text-center shadow-2xl"
            >
                {/* Icon Core */}
                <div className="flex justify-center mb-8">
                    <div className="relative">
                        <motion.div 
                            animate={{ rotate: 360 }}
                            transition={{ duration: 20, repeat: Infinity, ease: 'linear' }}
                            className="absolute -inset-4 border border-dashed border-blue-500/30 rounded-full"
                        />
                        <div className="w-20 h-20 bg-gradient-to-br from-blue-600 to-indigo-700 rounded-3xl flex items-center justify-center text-white shadow-xl shadow-blue-900/40 transform rotate-3">
                            <Lock size={36} strokeWidth={1.5} className="-rotate-3" />
                        </div>
                        <motion.div 
                            animate={{ opacity: [0.4, 1, 0.4] }}
                            transition={{ duration: 2, repeat: Infinity }}
                            className="absolute -right-2 -bottom-2 w-8 h-8 bg-black border border-white/20 rounded-xl flex items-center justify-center text-blue-400"
                        >
                            <Terminal size={14} />
                        </motion.div>
                    </div>
                </div>

                {/* Content */}
                <h1 className="text-3xl font-extrabold text-white mb-4 tracking-tight">
                    Environment Locked
                </h1>
                <p className="text-slate-400 text-lg leading-relaxed mb-10">
                    We've temporarily paused user-facing features. The dashboard will remain hidden until system-wide <span className="text-blue-400 font-semibold italic">requirements</span> are established.
                </p>

                {/* Status Pills */}
                <div className="flex flex-wrap justify-center gap-3 mb-10">
                    {[
                        { icon: FileSearch, text: "Analyzing Specs", active: true },
                        { icon: Sparkles, text: "UI definitions pending", active: false }
                    ].map((status, i) => (
                        <div 
                            key={i} 
                            className={`px-4 py-2 rounded-full text-xs font-bold uppercase tracking-widest flex items-center gap-2 border ${
                                status.active 
                                ? 'bg-blue-500/10 border-blue-500/30 text-blue-400' 
                                : 'bg-white/5 border-white/10 text-slate-500'
                            }`}
                        >
                            <status.icon size={14} />
                            {status.text}
                        </div>
                    ))}
                </div>

                {/* Footer hint */}
                <div className="pt-8 border-t border-white/5 flex flex-col items-center">
                    <div className="flex items-center gap-3 text-slate-500 text-xs font-medium uppercase tracking-[0.2em] mb-4">
                        <div className="w-1.5 h-1.5 rounded-full bg-blue-500 animate-pulse" />
                        System Status: Awaiting Input
                    </div>
                </div>
            </motion.div>
        </motion.div>
    );
};

export default RequirementOverlay;
