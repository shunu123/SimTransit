import React from 'react';
import { motion } from 'framer-motion';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { 
    LayoutDashboard, 
    Bus, 
    User, 
    Settings, 
    LogOut,
    Search,
    Bell,
    Calendar,
    GraduationCap,
    MapPin,
    Phone,
    Mail,
    BookOpen,
    Building2,
    Clock,
    ChevronRight,
    SearchCheck
} from 'lucide-react';

const UserDetails = () => {
    const { user, logout } = useAuth();
    const navigate = useNavigate();

    if (!user) {
        navigate('/login');
        return null;
    }

    const InfoRow = ({ icon: Icon, label, value }) => (
        <div style={{ display: 'flex', alignItems: 'center', gap: '16px', marginBottom: '20px' }}>
            <div style={{ 
                width: '44px', 
                height: '44px', 
                borderRadius: '12px', 
                backgroundColor: '#F5F7FF', 
                display: 'flex', 
                alignItems: 'center', 
                justifyContent: 'center',
                color: '#2D5BFF'
            }}>
                <Icon size={20} />
            </div>
            <div>
                <p style={{ fontSize: '11px', color: '#8A92A6', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.5px', marginBottom: '2px' }}>{label}</p>
                <p style={{ fontSize: '15px', color: '#1A1D23', fontWeight: '600' }}>{value || 'Not assigned'}</p>
            </div>
        </div>
    );

    return (
        <div style={{ 
            display: 'flex', 
            flexDirection: 'column',
            justifyContent: 'center',
            alignItems: 'center',
            minHeight: '100vh', 
            backgroundColor: '#0F172A', 
            fontFamily: "'Inter', sans-serif",
            padding: '40px',
            position: 'relative',
            overflow: 'hidden'
        }}>
            {/* Animated Background Elements */}
            <motion.div 
                animate={{ 
                    scale: [1, 1.2, 1],
                    rotate: [0, 90, 0],
                    opacity: [0.3, 0.5, 0.3]
                }}
                transition={{ duration: 20, repeat: Infinity, ease: "linear" }}
                style={{
                    position: 'absolute',
                    top: '-10%',
                    right: '-10%',
                    width: '600px',
                    height: '600px',
                    borderRadius: '50%',
                    background: 'radial-gradient(circle, rgba(45, 91, 255, 0.2) 0%, transparent 70%)',
                    filter: 'blur(80px)',
                    zIndex: 0
                }}
            />
            <motion.div 
                animate={{ 
                    scale: [1.2, 1, 1.2],
                    rotate: [0, -90, 0],
                    opacity: [0.2, 0.4, 0.2]
                }}
                transition={{ duration: 15, repeat: Infinity, ease: "linear" }}
                style={{
                    position: 'absolute',
                    bottom: '-10%',
                    left: '-10%',
                    width: '500px',
                    height: '500px',
                    borderRadius: '50%',
                    background: 'radial-gradient(circle, rgba(255, 77, 129, 0.15) 0%, transparent 70%)',
                    filter: 'blur(80px)',
                    zIndex: 0
                }}
            />

            <motion.div 
                initial={{ opacity: 0, scale: 0.9, y: 30 }}
                animate={{ opacity: 1, scale: 1, y: 0 }}
                transition={{ duration: 0.6, ease: "easeOut" }}
                style={{
                    backgroundColor: 'rgba(255, 255, 255, 0.03)',
                    backdropFilter: 'blur(20px)',
                    borderRadius: '40px',
                    padding: '56px',
                    width: '100%',
                    maxWidth: '580px',
                    boxShadow: '0 25px 80px rgba(0, 0, 0, 0.5)',
                    border: '1px solid rgba(255, 255, 255, 0.1)',
                    position: 'relative',
                    zIndex: 1
                }}
            >
                {/* Header Section */}
                <div style={{ textAlign: 'center', marginBottom: '48px' }}>
                    <motion.div 
                        initial={{ scale: 0 }}
                        animate={{ scale: 1 }}
                        transition={{ type: 'spring', damping: 12, stiffness: 200, delay: 0.2 }}
                        style={{ 
                            width: '100px', 
                            height: '100px', 
                            borderRadius: '35px', 
                            background: 'linear-gradient(135deg, #2D5BFF 0%, #7C3AED 100%)', 
                            margin: '0 auto 24px',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            color: 'white',
                            fontSize: '40px',
                            fontWeight: '900',
                            boxShadow: '0 20px 40px rgba(45, 91, 255, 0.4)',
                            position: 'relative'
                        }}
                    >
                        {user.first_name?.[0].toUpperCase()}
                        <motion.div 
                            animate={{ opacity: [0.5, 1, 0.5] }}
                            transition={{ duration: 2, repeat: Infinity }}
                            style={{
                                position: 'absolute',
                                inset: '-4px',
                                border: '2px solid #2D5BFF',
                                borderRadius: '39px',
                                opacity: 0.5
                            }}
                        />
                    </motion.div>
                    <h1 style={{ fontSize: '32px', fontWeight: '900', color: '#FFFFFF', marginBottom: '12px', letterSpacing: '-0.5px' }}>
                        Welcome, {user.first_name}!
                    </h1>
                    <p style={{ fontSize: '16px', color: '#94A3B8', fontWeight: '500' }}>
                        Your personalized dashboard is ready
                    </p>
                </div>

                {/* Details Container */}
                <div style={{ 
                    display: 'flex',
                    flexDirection: 'column',
                    gap: '2px',
                    backgroundColor: 'rgba(255, 255, 255, 0.02)',
                    borderRadius: '28px',
                    padding: '12px',
                    marginBottom: '48px',
                    border: '1px solid rgba(255, 255, 255, 0.05)'
                }}>
                    {[
                        { icon: User, label: "Student Profile", value: `${user.first_name} ${user.last_name}` },
                        { icon: GraduationCap, label: "Identity", value: `Reg No: ${user.reg_no}` },
                        { icon: Building2, label: "Campus", value: user.college_name },
                        { icon: MapPin, label: "Assigned Stop", value: user.stop },
                    ].map((item, idx) => (
                        <motion.div 
                            key={idx}
                            initial={{ opacity: 0, x: -20 }}
                            animate={{ opacity: 1, x: 0 }}
                            transition={{ delay: 0.4 + (idx * 0.1) }}
                            style={{ 
                                display: 'flex', 
                                alignItems: 'center', 
                                gap: '20px', 
                                padding: '20px',
                                borderRadius: '20px',
                                transition: 'background 0.2s ease',
                                cursor: 'default'
                            }}
                            onMouseOver={(e) => e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.05)'}
                            onMouseOut={(e) => e.currentTarget.style.backgroundColor = 'transparent'}
                        >
                            <div style={{ 
                                width: '48px', 
                                height: '48px', 
                                borderRadius: '15px', 
                                backgroundColor: 'rgba(45, 91, 255, 0.15)', 
                                display: 'flex', 
                                alignItems: 'center', 
                                justify: 'center',
                                color: '#2D5BFF'
                            }}>
                                <item.icon size={22} />
                            </div>
                            <div>
                                <p style={{ fontSize: '12px', color: '#64748B', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '1px', marginBottom: '4px' }}>{item.label}</p>
                                <p style={{ fontSize: '17px', color: '#F8FAFC', fontWeight: '600' }}>{item.value || 'Not set'}</p>
                            </div>
                        </motion.div>
                    ))}
                </div>

                {/* Actions */}
                <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                    <motion.button 
                        whileHover={{ scale: 1.02 }}
                        whileTap={{ scale: 0.98 }}
                        onClick={() => navigate('/dashboard')}
                        style={{ 
                            width: '100%',
                            padding: '20px', 
                            background: 'linear-gradient(135deg, #2D5BFF 0%, #1D4ED8 100%)', 
                            color: 'white', 
                            borderRadius: '20px', 
                            fontWeight: '800', 
                            fontSize: '18px',
                            border: 'none',
                            cursor: 'pointer',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            gap: '12px',
                            boxShadow: '0 15px 35px rgba(45, 91, 255, 0.3)',
                            letterSpacing: '0.5px'
                        }}
                    >
                        Get Started <ChevronRight size={22} />
                    </motion.button>
                    
                    <button 
                        onClick={logout}
                        style={{ 
                            background: 'none', 
                            border: 'none', 
                            color: '#64748B', 
                            fontSize: '15px', 
                            fontWeight: '600', 
                            cursor: 'pointer',
                            transition: 'color 0.2s ease'
                        }}
                        onMouseOver={(e) => e.currentTarget.style.color = '#FFFFFF'}
                        onMouseOut={(e) => e.currentTarget.style.color = '#64748B'}
                    >
                        Switch Account
                    </button>
                </div>
            </motion.div>

            <style dangerouslySetInnerHTML={{ __html: `
                @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap');
                body { margin: 0; background: #0F172A; }
            `}} />
        </div>
    );
};

export default UserDetails;
