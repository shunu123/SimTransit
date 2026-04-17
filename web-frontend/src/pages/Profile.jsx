import React from 'react';
import { motion } from 'framer-motion';
import { 
    User, 
    Mail, 
    Phone, 
    MapPin, 
    GraduationCap, 
    Building2, 
    Clock, 
    Zap, 
    Activity, 
    ShieldCheck, 
    Settings, 
    LogOut, 
    ArrowLeft,
    ChevronRight,
    CreditCard,
    QrCode
} from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

const Profile = () => {
    const { user, logout } = useAuth();
    const navigate = useNavigate();

    if (!user) {
        navigate('/login');
        return null;
    }

    const containerVariants = {
        hidden: { opacity: 0 },
        visible: {
            opacity: 1,
            transition: { staggerChildren: 0.1 }
        }
    };

    const itemVariants = {
        hidden: { y: 20, opacity: 0 },
        visible: { y: 0, opacity: 1 }
    };

    return (
        <div className="min-h-screen bg-[#050505] text-white p-6 md:p-12 font-sans selection:bg-[#3B5BDB]">
            {/* Ambient Background */}
            <div className="absolute inset-0 pointer-events-none overflow-hidden">
                <div className="absolute top-[-10%] right-[-10%] w-[50%] h-[50%] bg-[#3B5BDB]/10 blur-[120px] rounded-full" />
                <div className="absolute bottom-[-10%] left-[-10%] w-[50%] h-[50%] bg-[#f59e0b]/5 blur-[120px] rounded-full" />
            </div>

            <main className="max-w-7xl mx-auto relative z-10">
                {/* Header Section */}
                <div className="flex items-center justify-between mb-12">
                    <button 
                        onClick={() => navigate('/dashboard')}
                        className="group flex items-center gap-3 px-5 py-2.5 bg-white/[0.03] border border-white/10 rounded-2xl hover:bg-white/10 transition-all active:scale-95"
                    >
                        <ArrowLeft size={18} className="text-[#f59e0b] group-hover:-translate-x-1 transition-transform" />
                        <span className="text-[10px] font-black uppercase tracking-[0.2em] text-white/70">Back to Hub</span>
                    </button>
                    
                    <div className="flex items-center gap-4">
                        <div className="text-right hidden sm:block">
                            <p className="text-[10px] font-black text-[#f59e0b] uppercase tracking-[0.3em]">System Token</p>
                            <p className="text-xs font-bold text-white/40">{user.reg_no || 'STU-8829'}</p>
                        </div>
                        <button 
                            onClick={logout}
                            className="p-3 bg-red-500/10 border border-red-500/20 rounded-2xl text-red-500 hover:bg-red-500 hover:text-white transition-all active:scale-95"
                        >
                            <LogOut size={20} />
                        </button>
                    </div>
                </div>

                <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
                    {/* Left Column: ID Card & Quick Info */}
                    <div className="lg:col-span-4 space-y-8">
                        {/* Digital Bus Pass */}
                        <motion.div 
                            initial={{ scale: 0.9, opacity: 0 }}
                            animate={{ scale: 1, opacity: 1 }}
                            className="relative group pt-12"
                        >
                            <div className="absolute inset-0 bg-gradient-to-br from-[#3B5BDB] to-[#7C3AED] blur-3xl opacity-20 group-hover:opacity-30 transition-opacity" />
                            <div className="relative bg-gradient-to-br from-[#1a1a1a] to-[#0a0a0a] border border-white/10 rounded-[32px] p-8 overflow-hidden shadow-2xl">
                                <div className="absolute top-0 right-0 p-8 opacity-5">
                                    <Bus size={120} strokeWidth={1} />
                                </div>
                                
                                <div className="flex justify-between items-start mb-12">
                                    <div className="w-16 h-16 bg-gradient-to-br from-[#f59e0b] to-[#d97706] rounded-2xl flex items-center justify-center text-black shadow-xl">
                                        <QrCode size={32} />
                                    </div>
                                    <div className="text-right">
                                        <p className="text-[10px] font-black text-white/20 uppercase tracking-[0.4em] mb-1">Transit Class</p>
                                        <span className="px-3 py-1 bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 rounded-full text-[9px] font-black uppercase tracking-widest">Active Pass</span>
                                    </div>
                                </div>

                                <div className="space-y-6">
                                    <div>
                                        <p className="text-[10px] font-black text-white/30 uppercase tracking-[0.3em] mb-1">Pass Holder</p>
                                        <h2 className="text-2xl font-black tracking-tighter uppercase">{user.first_name} {user.last_name || user.name}</h2>
                                    </div>
                                    <div className="flex justify-between items-end">
                                        <div>
                                            <p className="text-[10px] font-black text-white/30 uppercase tracking-[0.3em] mb-1">Route Assignment</p>
                                            <p className="text-sm font-bold text-white/80">{user.stop || 'North Campus Express'}</p>
                                        </div>
                                        <div className="text-right">
                                            <p className="text-[11px] font-black text-white font-mono tracking-widest opacity-40">SIM-PK-2026</p>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </motion.div>

                        {/* Recent Activity Card */}
                        <div className="bg-white/[0.02] border border-white/5 rounded-[32px] p-8">
                            <h3 className="text-xs font-black uppercase tracking-[0.3em] text-[#f59e0b] mb-6 flex items-center gap-2">
                                <Activity size={16} /> Recent Commutes
                            </h3>
                            <div className="space-y-4">
                                {[
                                    { date: 'Today', time: '08:45 AM', stop: 'Main Gate', status: 'Completed' },
                                    { date: 'Yesterday', time: '05:20 PM', stop: 'Central Hub', status: 'Completed' },
                                    { date: '15 Apr', time: '08:30 AM', stop: 'Main Gate', status: 'Delayed' },
                                ].map((trip, i) => (
                                    <div key={i} className="flex items-center justify-between p-4 bg-white/[0.03] border border-white/5 rounded-2xl hover:bg-white/[0.05] transition-colors">
                                        <div className="flex gap-4 items-center">
                                            <div className={`w-2 h-2 rounded-full ${trip.status === 'Completed' ? 'bg-emerald-500' : 'bg-amber-500'}`} />
                                            <div>
                                                <p className="text-xs font-bold text-white/80">{trip.stop}</p>
                                                <p className="text-[9px] font-bold text-white/20 uppercase tracking-widest">{trip.date} • {trip.time}</p>
                                            </div>
                                        </div>
                                        <ChevronRight size={14} className="text-white/10" />
                                    </div>
                                ))}
                            </div>
                        </div>
                    </div>

                    {/* Right Column: Detailed Info & Stats */}
                    <div className="lg:col-span-8 space-y-8">
                        {/* Profile Header Stats */}
                        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                            {[
                                { label: 'Total Distance', value: '428km', icon: Globe, color: 'text-blue-400' },
                                { label: 'Time Saved', value: '12h', icon: Clock, color: 'text-[#f59e0b]' },
                                { label: 'Trips Taken', value: '84', icon: Bus, color: 'text-emerald-400' },
                                { label: 'Credits Remaining', value: '₹2,450', icon: CreditCard, color: 'text-purple-400' },
                            ].map((stat, i) => (
                                <motion.div 
                                    key={i}
                                    initial={{ opacity: 0, y: 10 }}
                                    animate={{ opacity: 1, y: 0 }}
                                    transition={{ delay: 0.1 * i }}
                                    className="bg-white/[0.03] border border-white/10 rounded-3xl p-6 hover:bg-white/[0.06] transition-all group"
                                >
                                    <div className={`w-10 h-10 rounded-xl bg-white/5 flex items-center justify-center mb-4 ${stat.color} group-hover:scale-110 transition-transform`}>
                                        <stat.icon size={20} />
                                    </div>
                                    <p className="text-[9px] font-black text-white/30 uppercase tracking-widest mb-1">{stat.label}</p>
                                    <p className="text-xl font-black text-white">{stat.value}</p>
                                </motion.div>
                            ))}
                        </div>

                        {/* Identity Details Section */}
                        <div className="bg-white/[0.02] border border-white/5 rounded-[40px] p-8 md:p-12">
                            <div className="flex items-center gap-4 mb-10">
                                <div className="w-16 h-16 rounded-2xl bg-[#3B5BDB]/20 flex items-center justify-center text-[#3B5BDB] border border-[#3B5BDB]/30 shadow-2xl">
                                    <User size={32} />
                                </div>
                                <div>
                                    <h3 className="text-2xl font-black tracking-tight text-white mb-1">Identity & Security</h3>
                                    <p className="text-[10px] font-black text-white/30 uppercase tracking-[0.4em]">Personal Information Vault</p>
                                </div>
                            </div>

                            <div className="grid grid-cols-1 md:grid-cols-2 gap-x-12 gap-y-10">
                                {[
                                    { icon: User, label: 'Full Legal Name', value: `${user.first_name} ${user.last_name}` },
                                    { icon: GraduationCap, label: 'Registration ID', value: user.reg_no },
                                    { icon: Building2, label: 'Institution/College', value: user.college_name },
                                    { icon: GraduationCap, label: 'Department/Branch', value: user.department },
                                    { icon: Mail, label: 'Email Address', value: user.email || `${user.reg_no}@college.edu` },
                                    { icon: Phone, label: 'Verified Mobile', value: user.mobile_no || '+91 99****8829' },
                                    { icon: MapPin, label: 'Assigned Boarding Stop', value: user.stop },
                                    { icon: ShieldCheck, label: 'Security Role', value: user.role || 'Verified Student' },
                                ].map((item, i) => (
                                    <div key={i} className="group cursor-default">
                                        <div className="flex items-center gap-4 mb-2">
                                            <item.icon size={16} className="text-[#f59e0b] opacity-40 group-hover:opacity-100 transition-opacity" />
                                            <p className="text-[10px] font-black text-white/20 uppercase tracking-widest">{item.label}</p>
                                        </div>
                                        <p className="text-lg font-black text-white/80 group-hover:text-white transition-colors pl-8">{item.value || 'Not Disclosed'}</p>
                                    </div>
                                ))}
                            </div>
                        </div>

                        {/* System Actions */}
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                            <button className="flex items-center justify-between px-8 py-6 bg-white/5 border border-white/10 rounded-3xl hover:bg-white/10 transition-all group">
                                <div className="flex items-center gap-4">
                                    <Settings className="text-white/30 group-hover:text-[#3B5BDB] transition-colors" />
                                    <span className="text-xs font-black uppercase tracking-widest text-white/70 group-hover:text-white">Account Preferences</span>
                                </div>
                                <ChevronRight className="text-white/10 group-hover:text-white" size={18} />
                            </button>
                            <button className="flex items-center justify-between px-8 py-6 bg-white/5 border border-white/10 rounded-3xl hover:bg-white/10 transition-all group">
                                <div className="flex items-center gap-4">
                                    <ShieldCheck className="text-white/30 group-hover:text-emerald-500 transition-colors" />
                                    <span className="text-xs font-black uppercase tracking-widest text-white/70 group-hover:text-white">Request Official Pass</span>
                                </div>
                                <ChevronRight className="text-white/10 group-hover:text-white" size={18} />
                            </button>
                        </div>
                    </div>
                </div>
            </main>
        </div>
    );
};

export default Profile;
