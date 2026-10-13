name: face_attendance
description: AI-powered face recognition attendance for colleges

# Pilot Plan for One Real Class
## Timeline: 4 weeks

### Week 1: Setup
- Create Firebase project, deploy rules
- Add teachers and class structure in Firestore
- Install app on teacher's Android device

### Week 2: Enrollment Drive  
- Enroll 30-60 students with consent forms
- Test dry run: 3 face scan sessions
- Tune thresholds based on initial accuracy

### Week 3: Supervised Use
- Teacher scans + manually verifies against register
- Log discrepancies, fix borderline cases
- Measure scan time vs. manual call (target: 3x faster)

### Week 4: Live Deployment
- Independent teacher operation
- Weekly accuracy audit
- Monthly report generation and download
