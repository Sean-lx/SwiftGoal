//
//  ManagePlayersViewController.swift
//  SwiftGoal
//
//  Created by Martin Richter on 30/06/15.
//  Copyright (c) 2015 Martin Richter. All rights reserved.
//

import UIKit
import ReactiveCocoa

class ManagePlayersViewController: UITableViewController {

    private let playerCellIdentifier = "PlayerCell"
    private let (isActiveSignal, isActiveSink) = Signal<Bool, NoError>.pipe()
    private let viewModel: ManagePlayersViewModel

    // MARK: Lifecycle

    init(viewModel: ManagePlayersViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init!(coder aDecoder: NSCoder!) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.rowHeight = 60
        tableView.tableFooterView = UIView() // Prevent empty rows at bottom

        tableView.registerClass(PlayerCell.self, forCellReuseIdentifier: playerCellIdentifier)

        self.refreshControl = UIRefreshControl()
        self.refreshControl?.addTarget(self,
            action: Selector("refreshControlTriggered"),
            forControlEvents: .ValueChanged
        )

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .Add,
            target: self,
            action: Selector("addPlayerButtonTapped")
        )

        bindViewModel()
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        sendNext(isActiveSink, true)
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)

        sendNext(isActiveSink, false)
    }

    // MARK: Bindings

    private func bindViewModel() {
        self.title = viewModel.title

        viewModel.active <~ isActiveSignal
        viewModel.contentChangesSignal
            |> observeOn(UIScheduler())
            |> observe(next: { [weak self] changeset in
                self?.tableView.beginUpdates()
                self?.tableView.deleteRowsAtIndexPaths(changeset.deletions, withRowAnimation: .Left)
                self?.tableView.insertRowsAtIndexPaths(changeset.insertions, withRowAnimation: .Automatic)
                self?.tableView.endUpdates()
            })
        viewModel.isLoadingSignal
            |> observeOn(UIScheduler())
            |> observe(next: { [weak self] isLoading in
                if !isLoading {
                    self?.refreshControl?.endRefreshing()
                }
            })
    }

    // MARK: User Interaction

    func addPlayerButtonTapped() {
        let newPlayerViewController = self.newPlayerViewController()
        presentViewController(newPlayerViewController, animated: true, completion: nil)
    }

    func refreshControlTriggered() {
        sendNext(viewModel.refreshSink, ())
    }

    // MARK: UITableViewDataSource

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return viewModel.numberOfSections()
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfPlayersInSection(section)
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(playerCellIdentifier, forIndexPath: indexPath) as! PlayerCell

        let (row, section) = (indexPath.row, indexPath.section)

        cell.nameLabel.enabled = viewModel.canSelectPlayerAtIndexPath(indexPath)
        cell.nameLabel.text = viewModel.playerNameAtIndexPath(indexPath)
        cell.accessoryType = viewModel.isPlayerSelectedAtIndexPath(indexPath) ? .Checkmark : .None

        return cell
    }

    // MARK: UITableViewDelegate

    override func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        return viewModel.canSelectPlayerAtIndexPath(indexPath) ? indexPath : nil
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)

        let (row, section) = (indexPath.row, indexPath.section)
        let cell = tableView.cellForRowAtIndexPath(indexPath)

        if viewModel.isPlayerSelectedAtIndexPath(indexPath) {
            viewModel.deselectPlayerAtIndexPath(indexPath)
            cell?.accessoryType = .None
        } else {
            viewModel.selectPlayerAtIndexPath(indexPath)
            cell?.accessoryType = .Checkmark
        }
    }

    // MARK: Private Helpers

    private func newPlayerViewController() -> UIViewController {
        let newPlayerViewController = UIAlertController(
            title: "New Player",
            message: nil,
            preferredStyle: .Alert
        )

        // Add user actions
        newPlayerViewController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        let saveAction = UIAlertAction(title: "Save", style: .Default, handler: { [weak self] _ in
            self?.viewModel.saveAction.apply().start()
        })
        newPlayerViewController.addAction(saveAction)

        // Allow saving only with valid input
        viewModel.inputIsValid.producer.start(next: { isValid in
            saveAction.enabled = isValid
        })

        // Add user input fields
        newPlayerViewController.addTextFieldWithConfigurationHandler { textField in
            textField.placeholder = "Player name"
        }

        // Forward text input to view model
        if let nameField = newPlayerViewController.textFields?.first as? UITextField {
            viewModel.playerName <~ nameField.signalProducer()
        }

        return newPlayerViewController
    }
}
