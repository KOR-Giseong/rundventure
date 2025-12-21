// [추가] 권한 종류를 관리하기 위한 Enum
enum AdminPermission {
  canSendNotifications,
  canManageUsers,
  canManageAnnouncements,
  canManageChallenges,
  canManageFreeBoard,
  canManageAdminRoles
}

// [추가] Enum에 따른 한글 레이블
const Map<AdminPermission, String> permissionLabels = {
  AdminPermission.canSendNotifications: '알림 전송',
  AdminPermission.canManageUsers: '사용자 정보 수정/삭제',
  AdminPermission.canManageAnnouncements: '공지사항 관리',
  AdminPermission.canManageChallenges: '챌린지 게시물 관리',
  AdminPermission.canManageFreeBoard: '자유게시판 관리',
  AdminPermission.canManageAdminRoles: '관리자 임명/해제',
};