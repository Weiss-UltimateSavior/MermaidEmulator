import { AppTheme } from '../common/Theme';
import { PageTopBar } from '../components/CommonWidgets';

@Component
export struct KernelView {
  build() {
    Column() {
      PageTopBar({ title: '内核管理' })
    }
    .width('100%')
    .height('100%')
    .padding({ left: AppTheme.pagePadding, right: AppTheme.pagePadding, bottom: 84 })
  }
}
