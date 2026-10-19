import {Suspense, type ReactNode} from 'react';
import Workspace from '@/components/workspace';
import Loading from '@/components/workspace-loading';

export default function WorkspaceLayout({children}: {children: ReactNode}) {
  return <>{children}<Suspense fallback={<Loading/>}><Workspace/></Suspense></>;
}
