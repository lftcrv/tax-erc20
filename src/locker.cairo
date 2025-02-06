pub mod locker;
pub mod interface;

pub use interface::{IGradualLocker, IGradualLockerDispatcher, IGradualLockerDispatcherTrait};
pub use locker::{GradualLocker, GradualLocker::TokenLocked};
