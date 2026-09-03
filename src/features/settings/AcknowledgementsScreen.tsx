import React from 'react';

import { HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import { ListGroup, ParentNavBar, ParentPage } from './ParentKit';

/**
 * Third-party notices.
 *
 * There is no render for this screen because there is nothing in it to draw:
 * HopPotty links no third-party code, so the honest version is one paragraph
 * saying so. An empty list here would read as a bug, and a page of borrowed
 * licence text would be a lie about what the app contains.
 *
 * The notices list is data rather than a hard-coded nothing, so the day the app
 * does link something this screen already knows how to show it.
 */

export interface Acknowledgement {
  readonly id: string;
  readonly name: string;
  /** The licence, named — "MIT", "Apache-2.0". */
  readonly licence: string;
  readonly onOpen?: () => void;
}

export interface AcknowledgementsScreenProps {
  notices?: readonly Acknowledgement[];
  onBack?: () => void;
}

const NO_THIRD_PARTY =
  'Every event, star and note lives on your device. There is no account, no analytics, and nothing is uploaded.';

const NOTHING_LINKED = 'HopPotty links no third-party code.';

export function AcknowledgementsScreen({
  notices = [],
  onBack,
}: AcknowledgementsScreenProps): React.ReactElement {
  const theme = useHopTheme();

  return (
    <ParentPage>
      <ParentNavBar title="Acknowledgements" backLabel="Settings" onBack={onBack} />

      <HopText variant="parentBody" tone="secondary">
        {NO_THIRD_PARTY}
      </HopText>

      {notices.length === 0 ? (
        <HopText variant="parentBody" tone="secondary" style={{ paddingTop: theme.spacing.xs }}>
          {NOTHING_LINKED}
        </HopText>
      ) : (
        <ListGroup
          header="Included code"
          rows={notices.map((notice) => ({
            id: notice.id,
            label: notice.name,
            value: notice.licence,
            chevron: notice.onOpen !== undefined,
            onPress: notice.onOpen,
          }))}
        />
      )}
    </ParentPage>
  );
}
