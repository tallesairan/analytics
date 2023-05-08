import React, { Fragment } from 'react'
import { Menu, Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import * as storage from '../../util/storage'

import Funnel from './funnel'
import Conversions from './conversions'

const ACTIVE_CLASS = 'inline-block h-5 text-indigo-700 dark:text-indigo-500 font-bold active-prop-heading truncate text-left'
const DEFAULT_CLASS = 'hover:text-indigo-600 cursor-pointer truncate text-left'
const CONVERSIONS = 'conversions'



// export default function Behaviours({ query, site })
//   const [tab, setMode] = useState('conversions')
//   const tabs = <Tabs tab={tab} setTab={setTab} site={site} />
//
//   if (site.flags.funnels) {
//     const selectedFunnel = site.funnels.find(funnel => funnel.name === tab)
//     const funnelNames = site.funnels.map(({ name }) => name)
//
//     return (
//       <div className="w-full p-4 bg-white rounded shadow-xl dark:bg-gray-825">
//         {tab == 'conversions' && <Conversions tabs={tabs} query={query} site={site} />}
//         {funnelNames.includes(tab) && <Funnel tabs={tabs} funnel={selectedFunnel} query={query} site={site} />}
//       </div>
//     )
//   } else {
//     return <div className="w-full p-4 bg-white rounded shadow-xl dark:bg-gray-825">
//       {tab == 'conversions' && <Conversions tabs={tabs} query={query} site={site} />}
//     </div>
//   }
// }

export default class Behaviours extends React.Component {
  constructor(props) {
    super(props)
    this.tabKey = `behavioursTab__${props.site.domain}`
    const storedTab = storage.getItem(this.tabKey)
    this.state = {
      mode: storedTab || CONVERSIONS
    }
  }

  setMode(mode) {
    console.info('setMode', mode)
    return () => {
      storage.setItem(this.tabKey, mode)
      this.setState({ mode })
    }
  }

  tabFunnelPicker() {
    const funnelNames = this.props.site.funnels.map(({ name }) => name)

    return <Menu as="div" className="relative inline-block text-left">
      <div>
        <Menu.Button className="inline-flex justify-between focus:outline-none">
          <span className={funnelNames.includes(this.state.mode) ? ACTIVE_CLASS : DEFAULT_CLASS}>Funnels</span>
          <ChevronDownIcon className="-mr-1 ml-1 h-4 w-4" aria-hidden="true" />
        </Menu.Button>
      </div>

      <Transition
        as={Fragment}
        enter="transition ease-out duration-100"
        enterFrom="transform opacity-0 scale-95"
        enterTo="transform opacity-100 scale-100"
        leave="transition ease-in duration-75"
        leaveFrom="transform opacity-100 scale-100"
        leaveTo="transform opacity-0 scale-95"
      >
        <Menu.Items className="text-left origin-top-right absolute right-0 mt-2 w-56 rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5 focus:outline-none z-10">
          <div className="py-1">
            {funnelNames.map((option) => {
              return (
                <Menu.Item key={option}>
                  {({ active }) => (
                    <span
                      onClick={this.setMode(option)}
                      className={classNames(
                        active ? 'bg-gray-100 dark:bg-gray-900 text-gray-900 dark:text-gray-200 cursor-pointer' : 'text-gray-700 dark:text-gray-200',
                        'block px-4 py-2 text-sm',
                        this.state.mode === option ? 'font-bold' : ''
                      )}
                    >
                      {option}
                    </span>
                  )}
                </Menu.Item>
              )
            })}
          </div>
        </Menu.Items>
      </Transition>
    </Menu>
  }

  tabConversions() {
    return (
      <div className={classNames({ [ACTIVE_CLASS]: this.state.mode == CONVERSIONS, [DEFAULT_CLASS]: this.state.mode !== CONVERSIONS })} onClick={this.setMode(CONVERSIONS)}>Conversions</div>
    )
  }

  tabs() {
    console.info('tabs', this)
    return (
      <div className="flex text-xs font-medium text-gray-500 dark:text-gray-400 space-x-2">
        {this.tabConversions()}
        {this.tabFunnelPicker()}
      </div>
    )
  }

  renderContent() {
    const funnelNames = this.props.site.funnels.map(({ name }) => name)
    const selectedFunnel = this.props.site.funnels.find(funnel => funnel.name === this.state.mode)

    switch (this.state.mode) {
      case CONVERSIONS:
        return <Conversions tabs={this.tabs()} site={this.props.site} query={this.props.query} />
      default:
        if (funnelNames.includes(this.state.mode)) {
          console.info('yess', this.state.mode)

          return <Funnel tabs={this.tabs()} funnel={selectedFunnel} query={this.props.query} site={this.props.site} />
        }
    }
  }

  render() {
    console.info('renderxxx')
    return (<div className="w-full p-4 bg-white rounded shadow-xl dark:bg-gray-825">
      {this.renderContent()}
    </div>)
  }
}
