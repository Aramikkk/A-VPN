import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/home/widget/avpn_home_body.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';

void main() {
  test('shows the active outbound when the refreshed auto group has no selected tag', () {
    final group = OutboundInfo(tag: 'lowest', isGroup: true);
    final active = OutboundInfo(tag: 'pl5', tagDisplay: '🇵🇱 Sigma - Польша', urlTestDelay: 68);

    expect(autoPick(group, [group], fallback: active), same(active));
  });

  test('prefers the auto group selected outbound over the active fallback', () {
    final selected = OutboundInfo(tag: 'fi', tagDisplay: '🇫🇮 Sigma - Финляндия', urlTestDelay: 92);
    final group = OutboundInfo(tag: 'lowest', isGroup: true, groupSelectedTag: selected.tag);
    final active = OutboundInfo(tag: 'pl5', tagDisplay: '🇵🇱 Sigma - Польша', urlTestDelay: 68);

    expect(autoPick(group, [group, selected], fallback: active), same(selected));
  });

  test('uses the live ping when the auto-selected server has no measured ping', () {
    final selected = OutboundInfo(tag: 'ee', tagDisplay: '🇪🇪 Sigma - Эстония · БС');
    final group = OutboundInfo(tag: 'lowest', isGroup: true, groupSelectedTag: selected.tag);
    final active = OutboundInfo(tag: 'ee', tagDisplay: selected.tagDisplay, urlTestDelay: 223);

    expect(autoPick(group, [group, selected], fallback: active)?.urlTestDelay, 223);
  });

  test('shows the live ping for the selected server when its list entry is unmeasured', () {
    final selected = OutboundInfo(tag: 'ee', tagDisplay: '🇪🇪 Sigma - Эстония · БС');
    final active = OutboundInfo(tag: 'ee', urlTestDelay: 223);

    expect(displayedHomePingDelay(selected, active: active, selected: true), 223);
  });
}
