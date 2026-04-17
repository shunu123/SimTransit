import React, { useState, useRef, useEffect } from 'react';
import { User, Settings, FileText, LogOut, ChevronDown } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { motion, AnimatePresence } from 'framer-motion';

const UserProfile = () => {
    const { user, logout } = useAuth();
    const navigate = useNavigate();
    const [isOpen, setIsOpen] = useState(false);
    const menuRef = useRef(null);

    // Close on click outside
    useEffect(() => {
        const handleClickOutside = (event) => {
            if (menuRef.current && !menuRef.current.contains(event.target)) {
                setIsOpen(false);
            }
        };
        document.addEventListener('mousedown', handleClickOutside);
        return () => document.removeEventListener('mousedown', handleClickOutside);
    }, []);

    if (!user) return null;

    return (
        <div className="relative" ref={menuRef}>
            {/* Trigger Button */}
            <button 
                onClick={() => setIsOpen(!isOpen)}
                className="flex items-center gap-3 px-5 py-2.5 bg-white/[0.03] border border-white/[0.08] rounded-full hover:bg-white/[0.08] hover:border-white/20 transition-all duration-500 shadow-2xl active:scale-95 group"
            >
                <div className="w-8 h-8 rounded-full bg-gradient-to-br from-[var(--accent)] to-[var(--accent-secondary)] flex items-center justify-center text-white text-[10px] font-black shadow-[0_0_20px_rgba(99,102,241,0.2)]">
                    {user.name ? user.name[0].toUpperCase() : 'U'}
                </div>
                <span className="text-[10px] font-black text-white/70 uppercase tracking-[0.2em] group-hover:text-white transition-colors">{user.name || 'User'}</span>
                <ChevronDown size={14} className={`text-white/20 transition-transform duration-500 ${isOpen ? 'rotate-180' : ''} group-hover:text-white`} />
            </button>

            {/* Dropdown Menu */}
            <AnimatePresence>
                {isOpen && (
                    <motion.div
                        initial={{ opacity: 0, y: 12, scale: 0.98 }}
                        animate={{ opacity: 1, y: 0, scale: 1 }}
                        exit={{ opacity: 0, y: 8, scale: 0.98 }}
                        transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
                        className="absolute right-0 mt-4 w-72 bg-[#050505]/95 backdrop-blur-3xl border border-white/10 rounded-[var(--radius-lg)] shadow-[0_40px_80px_rgba(0,0,0,0.7)] z-[10000] overflow-hidden"
                    >
                        {/* User Details */}
                        <div className="p-6 border-b border-white/[0.05] bg-white/[0.01]">
                            <p className="text-[9px] font-black text-white/15 uppercase tracking-[0.4em]">Verified Token</p>
                            <p className="text-base font-black text-white mt-2 tracking-tight">{user.name}</p>
                            <p className="text-[11px] text-white/30 truncate font-bold mt-1 tracking-wide">{user.email || user.reg_no}</p>
                        </div>

                        {/* Actions */}
                        <div className="p-2.5 flex flex-col gap-1">
                            <button 
                                onClick={() => { navigate('/profile'); setIsOpen(false); }}
                                className="w-full flex items-center gap-4 px-4 py-3 text-sm text-white/60 hover:text-white hover:bg-white/[0.04] rounded-xl transition-all group"
                            >
                                <User size={16} className="text-white/20 group-hover:text-[var(--accent)] transition-colors" />
                                <span className="text-[11px] font-black uppercase tracking-widest">Profile Identity</span>
                            </button>
                            <button className="w-full flex items-center gap-4 px-4 py-3 text-sm text-white/60 hover:text-white hover:bg-white/[0.04] rounded-xl transition-all group">
                                <Settings size={16} className="text-white/20 group-hover:text-[var(--accent)] transition-colors" />
                                <span className="text-[11px] font-black uppercase tracking-widest">System Config</span>
                            </button>
                            <button className="w-full flex items-center gap-4 px-4 py-3 text-sm text-white/60 hover:text-white hover:bg-white/[0.04] rounded-xl transition-all group">
                                <FileText size={16} className="text-white/20 group-hover:text-[var(--accent)] transition-colors" />
                                <span className="text-[11px] font-black uppercase tracking-widest">Data Reports</span>
                            </button>
                        </div>

                        {/* Logout */}
                        <div className="p-2.5 border-t border-white/[0.05]">
                            <button 
                                onClick={logout}
                                className="w-full flex items-center gap-4 px-4 py-3 text-sm text-red-500/70 hover:text-red-500 hover:bg-red-500/5 rounded-xl transition-all group"
                            >
                                <LogOut size={16} className="text-red-500/30 group-hover:text-red-500 transition-colors" />
                                <span className="text-[11px] font-black uppercase tracking-widest">Terminate Session</span>
                            </button>
                        </div>
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    );
};

export default UserProfile;
